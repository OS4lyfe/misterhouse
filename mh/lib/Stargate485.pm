#!/usr/bin/perl                                                                                 
#
#    Add these entries to your mh.ini file:
#
#    Stargate485_serial_port=COM2
# 
#    bsobel@vipmail.com'
#    July 11, 2000
#
#

use strict;

# This needs to be available to both Stargate485 and StargateLCDKeypad
my @lcdkeypad_object_list;
my @thermostat_object_list;
my (@stargate485_command_list, $transmitok, $temp);

package Stargate485;

my ($temp);

#
# This code create the serial port and registers the callbacks we need
#
sub serial_startup
{
    if ($::config_parms{Stargate485_serial_port}) 
    {
        my($speed) = $::config_parms{Stargate485_baudrate} || 9600;
        if (&::serial_port_create('Stargate485', $::config_parms{Stargate485_serial_port}, $speed, 'none')) 
        {
            init($::Serial_Ports{Stargate485}{object}); 
            &::MainLoop_pre_add_hook( \&Stargate485::UserCodePreHook,   1 );
            &::MainLoop_post_add_hook( \&Stargate485::UserCodePostHook, 1 );
        }
    }
}

sub init 
{
    my ($serial_port) = @_;
    $::Serial_Ports{'Stargate485'}{process_data} = 1;

    $serial_port->error_msg(0);  
    $serial_port->user_msg(1);
#    $serial_port->debug(1);

#    $serial_port->parity_enable(1);		
    $serial_port->baudrate(9600);
    $serial_port->databits(8);
    $serial_port->parity("none");
    $serial_port->parity_enable(0);
    $serial_port->stopbits(1);

    $serial_port->handshake("none");         #&? Should this be DTR?

    $serial_port->dtr_active(1);		
    $serial_port->rts_active(0);		
    select (undef, undef, undef, .100); 	# Sleep a bit
    ::print_log "Stargate485 init\n";

    $transmitok = 1;
}

sub UserCodePreHook
{
    # Special case startup but notifying already created objects about it and then return.
    if($::Startup)
    {
        SetKeypadStates('all','startup');
        return;
    }

    if($::New_Msecond_100)
    {
        my $data;
        unless ($data = $::Serial_Ports{'Stargate485'}{object}->input) 
        {
            # If we do not do this, we may get endless error messages.
            $::Serial_Ports{'Stargate485'}{object}->reset_error;
        }

        $::Serial_Ports{'Stargate485'}{data} .= $data if $data;

        print "  serial name=Stargate485 type=$::Serial_Ports{'Stargate485'}{datatype} data2=$::Serial_Ports{'Stargate485'}{data}...\n" 
            if $data and ($::config_parms{debug} eq 'serial' or $::config_parms{debug} eq 'Stargate485');

        # Check to see if we have a carrage return yet
        if ($::Serial_Ports{'Stargate485'}{data})
        {
            while (my($record, $remainder) = $::Serial_Ports{'Stargate485'}{data} =~ /(.+?)[\r\n]+(.*)/s) 
            {
                &::print_log("Data from Stargate485: $record.  remainder=$remainder.") if $::config_parms{debug} eq 'serial';
                $::Serial_Ports{'Stargate485'}{data_record} = $record;
                $::Serial_Ports{'Stargate485'}{data} = $remainder;
                if($::config_parms{debug} eq 'Stargate')
                {
                    print "Data: " . $record . "\n"  unless substr($record,1,2) eq 'TP' and (substr($record,5,1) eq 'Q' or substr($record,6,1) eq 'A');
                }

                # Look something like '$TP01D2cff         11' ?
                if(substr($record,0,3) eq '$TP')
                {
                    ParseKeypadData($record);
                }
                # Next look for thermostat responses to our request for status
                elsif(substr($record,0,4) eq 'A=MH')
                {
                    ParseThermostatData($record);
                }
            }
        }
    }    

    if(@stargate485_command_list > 0 && $transmitok && !$::Serial_Ports{'Stargate485'}{data})
    {
        $::Serial_Ports{Stargate485}{object}->rts_active(1);		
        select (undef, undef, undef, .10); 	# Sleep a bit

        $::Serial_Ports{Stargate485}{object}->write("\r");

        if(@stargate485_command_list > 0)
        {
            (my $output) = shift @stargate485_command_list;
            print "Stargate LCD Output: " .$output . "\n";
            $::Serial_Ports{Stargate485}{object}->write($output . "\r");
        }
        select (undef, undef, undef, .30); 	# Sleep a bit

        $::Serial_Ports{Stargate485}{object}->rts_active(0);		
        select (undef, undef, undef, .10); 	# Sleep a bit
    }
}

sub UserCodePostHook
{
    #
    # Reset data for _now functions
    #
    $::Serial_Ports{Stargate485}{data_record} = '';
}

sub ParseKeypadData
{
    my ($record) = @_;

    my $NewState;
    my $TargetLCD;

    # Extracr the keypad address
    $TargetLCD = substr($record,3,2);
    #print "Target: $TargetLCD\n";

    # Change it to 'D2cff         11'
    $record = substr($record,5);
    #print "Record: $record\n";

    # Is this a MACRO?
    if(substr($record,0,3) eq 'D2c')
    {
        # Set the generic 'macro triggered' state
        #SetKeypadStates($TargetLCD,'MACRO');

        # Set the specific 'macro triggered' state
        my $MacroId = substr($record,3,2);
        #print "MacroID = $MacroId\n";
        # Hex to decimal
        $MacroId = hex($MacroId) + 1;
        #print "MacroID decoded as: " . $MacroId . "\n";
        SetKeypadStates($TargetLCD,sprintf('macro%3.3d',$MacroId));
    }
}

sub SetKeypadStates
{
    my ($address, $state) = @_;

    #print "SetKeypadStats: $address $state\n";

    my $object;
    foreach $object (@lcdkeypad_object_list)
    {
        if(($address eq 'all') or ($object->{address} == 0) or ($object->{address} == $address))
        {
            $object->set($state);
        }
    }
}

sub ParseThermostatData
{
    my ($record) = @_;

    my $address = $1 if $record =~ /\sO=(\d+)/;

    my $object;
    foreach $object (@thermostat_object_list)
    {
        if($object->{address} == $address)
        {
            # For multi zoned systems we will need to loop thru the responses and get
            # the zone specific ones.  We apply the system settings to all zones.
            # This is not yet implemented (we don't have a multizoned system to 
            # test any code against)

            if($record =~ /\sT=(\d+)/)
            {
                $object->set_states_for_next_pass("temp") if($object->{temp} ne $1);
                $object->set_states_for_next_pass("temp:$1") if($object->{temp} ne $1);
                $object->{temp} = $1;
            }

            if($record =~ /\sSP=(\d+)/)
            {
                $object->set_states_for_next_pass("setpoint") if($object->{setpoint} ne $1);
                $object->set_states_for_next_pass("setpoint:$1") if($object->{setpoint} ne $1);
                $object->{setpoint} = $1;
            }

            if($record =~ /\sM=(O|H|C|A|I)/)
            {
                $object->set_states_for_next_pass("zonemode") if($object->{zonemode} ne $1);
                $object->set_states_for_next_pass("zonemode:$1") if($object->{zonemode} ne $1);
                $object->{zonemode} = $1;
            }

            if($record =~ /\sFM=(\d+)/)
            {
                $object->set_states_for_next_pass("zonefanmode") if($object->{zonefanmode} ne $1);
                $object->set_states_for_next_pass("zonefanmode:" . &StargateThermostat::ReturnString($1)) if($object->{zonefanmode} ne $1);
                $object->{zonefanmode} = $1;
            }

            if($record =~ /\sH1A=(\d+)/)
            {
                $object->set_states_for_next_pass("heatingstage1") if($object->{heatingstage1} ne $1);
                $object->set_states_for_next_pass("heatingstage1:" . &StargateThermostat::ReturnString($1)) if($object->{heatingstage1} ne $1);
                $object->{heatingstage1} = $1;
            }

            if($record =~ /\sH2A=(\d+)/)
            {
                $object->set_states_for_next_pass("heatingstage2") if($object->{heatingstage2} ne $1);
                $object->set_states_for_next_pass("heatingstage2:" . &StargateThermostat::ReturnString($1)) if($object->{heatingstage2} ne $1);
                $object->{heatingstage2} = $1;
            }

            if($record =~ /\sC1A=(\d+)/)
            {
                $object->set_states_for_next_pass("coolingstage1") if($object->{coolingstage1} ne $1);
                $object->set_states_for_next_pass("coolingstage1:" . &StargateThermostat::ReturnString($1)) if($object->{coolingstage1} ne $1);
                $object->{coolingstage1} = $1;
            }

            if($record =~ /\sC2A=(\d+)/)
            {
                $object->set_states_for_next_pass("coolingstage2") if($object->{coolingstage2} ne $1);
                $object->set_states_for_next_pass("coolingstage2:" . &StargateThermostat::ReturnString($1)) if($object->{coolingstage2} ne $1);
                $object->{coolingstage2} = $1;
            }

            if($record =~ /\sFA=(\d+)/)
            {
                $object->set_states_for_next_pass("fanstatus") if($object->{fanstatus} ne $1);
                $object->set_states_for_next_pass("fanstatus:" . &StargateThermostat::ReturnString($1)) if($object->{fanstatus} ne $1);
                $object->{fanstatus} = $1;
            }

            if($record =~ /\sSCP=(\d+)/)
            {
                $object->set_states_for_next_pass("shortcycle") if($object->{shortcycle} ne $1);
                $object->set_states_for_next_pass("shortcycle:" . &StargateThermostat::ReturnString($1)) if($object->{shortcycle} ne $1);
                $object->{shortcycle} = $1;
            }

            if($record =~ /\sSM=(O|H|C|A|I)/)
            {
                $object->set_states_for_next_pass("systemmode") if($object->{systemmode} ne $1);
                $object->set_states_for_next_pass("systemmode:" . &StargateThermostat::ReturnString($1)) if($object->{systemmode} ne $1);
                $object->{systemmode} = $1;
            }

            if($record =~ /\sSF=(\d+)/)
            {
                $object->set_states_for_next_pass("fancommand") if($object->{fancommand} ne $1);
                $object->set_states_for_next_pass("fancommand:" . &StargateThermostat::ReturnString($1)) if($object->{fancommand} ne $1);
                $object->{fancommand} = $1;
            }
        }
    }
}

1;
    
#
# Item object version (this lets us use object links and events)
#

# $TP from keypad.  01 address 
#$TP01D2cff         11

package StargateLCDKeypad;
@StargateLCDKeypad::ISA = ('Generic_Item');

sub new 
{
    my ($class, $address) = @_;

    my $self = {address => $address};
    bless $self, $class;

    push(@lcdkeypad_object_list,$self);

    return $self;
}

sub ClearScreen
{
    my ($self) = @_;
    my $output = "!TP" . sprintf("%2.2xC", $self->{address});
    push(@stargate485_command_list, $output);
}

sub GoToMenu
{
    my ($self, $menu) = @_;
    my $output = "!TP" . sprintf("%2.2xG%2.2x", $self->{address}, $menu-1);
    push(@stargate485_command_list, $output);
}

sub WriteText
{
    my ($self,$row,$text) = @_;
    my $output = "!TP" . sprintf("%2.2xT%2.2x0a%-10.10s00", $self->{address}, $row-1, $text);
    push(@stargate485_command_list, $output);
}

sub ChangeText
{
    my ($self,$menu,$row,$text) = @_;

    my $output = "!TP" . sprintf("%2.2xm%2.2x%2.2x80%-10.10s00", $self->{address}, $menu-1, $row-1, $text);
    push(@stargate485_command_list, $output);
}

sub InvertText
{
    my ($self,$menu,$row) = @_;

    my $output = "!TP" . sprintf("%2.2xm%2.2x%2.2x30          30", $self->{address}, $menu-1, $row-1);
    push(@stargate485_command_list, $output);
}

sub UnInvertText
{
    my ($self,$menu,$row) = @_;

    my $output = "!TP" . sprintf("%2.2xm%2.2x%2.2x30          00", $self->{address}, $menu-1, $row-1);
    push(@stargate485_command_list, $output);
}
1;

#
# Item object version (this lets us use object links and events)
#
package StargateThermostat;
@StargateThermostat::ISA = ('Generic_Item');

sub new 
{
    my ($class, $address, $zone) = @_;

    $zone = 1 if $zone == undef;
    my $self = {address => $address, zone => $zone};
    bless $self, $class;

    push(@thermostat_object_list,$self);

    #
    # This is data we get from our queries, default it here and then fill it in.  These map
    # closely to the RCS 485 thermostats but should be able to be updated for others.
    #
    $self->{temp}            = undef;   # T=74
    $self->{setpoint}        = undef;   # SP=77 
    $self->{zonemode}        = undef;   # M=0
    $self->{zonefanmode}     = undef;   # FM=0
    $self->{heatingstage1}   = undef;   # H1A=0
    $self->{heatingstage2}   = undef;   # H2A=0
    $self->{coolingstage2}   = undef;   # C1A=0
    $self->{coolingstage2}   = undef;   # C2A=0
    $self->{fanstatus}       = undef;   # FA=0
    $self->{shortcycle}      = undef;   # SCP=0
    $self->{systemmode}      = undef;;  # SM=A
    $self->{fancommand}      = undef;   # SF=0

    # Set available commands here
    # push(@{$$self{states}}, 'on','off','volume:max', 'volume:normal', 'volume:min','volume:+','volume:-','input:+','input:-');

    return $self;
}

sub set
{
    my ($self, $state) = @_;
    $self->SUPER::set($state);
}

sub state
{
    my ($self, $device) = @_;

    return $self->SUPER::state() unless defined $device;
    return undef if($self->{zone} == 0);

    SWITCH: for( $device )
    {
        /^address/i         && do { return $self->{address}};
        /^zone/i            && do { return $self->{zone}};

        /^temp/i            && do { return $self->{temp}};
        /^temperature/i     && do { return $self->{temp}};
        /^setpoint/i        && do { return $self->{setpoint}};
        /^zonemode/i        && do { return ReturnString($self->{zonemode})};
        /^zonefanmode/i     && do { return ReturnString($self->{zonefanmode})};

        /^heatingstage1/i   && do { return ReturnString($self->{heatingstage1})};
        /^heatingstage2/i   && do { return ReturnString($self->{heatingstage2})};
        /^coolingstage1/i   && do { return ReturnString($self->{coolingstage2})};
        /^coolingstage2/i   && do { return ReturnString($self->{coolingstage2})};

        /^fanstatus/i       && do { return ReturnString($self->{fanstatus})};
        /^shortcycle/i      && do { return ReturnString($self->{shortcycle})};
        /^scp/i             && do { return ReturnString($self->{shortcycle})};

        /^systemmode/i      && do { return ReturnString($self->{systemmode})};
        /^fancommand/i      && do { return ReturnString($self->{fancommand})};
    }

    return undef;
}

sub ReturnString
{
    my ($data) = @_;

    SWITCH: for ( $data )
    {
        /0/                 && do { return "off"};   
        /1/                 && do { return "on"};   
        /H/                 && do { return "heat"};   
        /C/                 && do { return "cool"};   
        /A/                 && do { return "auto"};   
        /I/                 && do { return "invalid"};   
    }
    return "unknown";
}


1;

