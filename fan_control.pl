#!/usr/local/bin/perl

###########################################################################
########################## Version 2.0 ####################################
###########################################################################

# Implementation of PID control scheme on Supermicro X10 series motherboards
# Maintains the constant GPU temperature by adjusting the duty cycles on periferal
# zone 1( FANA-FANC). CPU fans (FAN1-6) are being controlled by the motherboard
# by using "Optimal mode".

use POSIX qw(strftime);
use Time::Local;
use Term::ANSIColor;

################ CONFIG FILE #############################################
# You may edit it while script is running, not all values should be present
$config_file = '/home/ergot/fan_control/config.ini';

############### DEFAULT_VALUES ###########################################

$target_gpu_temp = 63;
$sleep_interval = 30;

$min_fan_duty = 25;
$max_fan_duty = 100;

$Kp = 4;
$Kd = 1;
$Ki = 0;

# fan duty cycle initial values
$fan_duty = 50;

$integral = 0;
$error = 0;
$error_old = 0;

sub round {
    return int($_[0] + 0.5);
}

sub get_power_reading {
    my $command = "ipmitool dcmi power reading | grep 'Instantaneous power'";
    my $output = `$command`;
    my @vals = split(" ", $output);
#    print "$output";
#    print "$vals[3]\n";
    return $vals[3];
}

sub get_gpu_temps {
    my $command = "nvidia-smi -q | grep 'GPU Current Temp'";
    my $output = `$command`;
    #print "$output\n";
    my @spl = split("\n", $output);
    my $max_temp = 0;
    my $avg_temp = 0;
    my $gpu_count = 0;

    foreach $line (@spl) {
    #    print "$line\n";
        my @vals = split(" ", $line);
        my $temp = "$vals[4]";

        $avg_temp += $temp;
        $gpu_count++;
        if ($temp > $max_temp) { $max_temp = $temp};
    }

    $avg_temp /= $gpu_count;

    return $max_temp, $avg_temp;
}

sub set_fan_duty {
    my $new_fan_duty = round($_[0]);
#    my $datetime = build_date_time_string();
#    if ($new_fan_duty != round($fan_duty)) {
        print "[$datetime] Changing fan duty:		$new_fan_duty % \n";
        `ipmitool raw 0x30 0x70 0x66 0x01 1 $new_fan_duty`;
#    }
}

sub build_date_time_string {
    my $datetimestring = strftime "%F %H:%M:%S", localtime;
    return $datetimestring;
}

sub calc_PID_correction {
    my ($error, $error_old) = @_;

    $integral += $error * $sleep_interval / 60;
    my $derivative = ($error - $error_old) * 60 / $sleep_interval;

    my $P = $Kp * $error * $sleep_interval / 60;
    my $I = $Ki * $integral;
    my $D = $Kd * $derivative;
    my $correction = $P + $I + $D;
    printf("[%s] P: %3.1f I: %3.1f D:% 3.1f sum: %3.1f \n", $datetime, $P, $I, $D, $correction);
#    print "[$datetime] P: $P I: $I D: $D sum: $correction \n";

    return $correction;
}


sub print_stats {
    my ($gpu_temp, $power) = @_;

    $gpu_temp_str = sprintf("%2.2fC", $gpu_temp);

    if ($gpu_temp <= $target_gpu_temp + 0.5) {
        $color = 'green';
    } else {
        $color = 'red';
    }

    printf("[%s] gpu_temp: %2.2fC ", $datetime, $gpu_temp_str);
#    print "[$datetime] gpu_temp: ", colored($gpu_temp_str, $color), " ";
    printf("power: %4dW\n", $power);
    
}

sub read_config {
    # read config file, if present
    if (do $config_file) {
        $target_gpu_temp = $config_Ta // $target_gpu_temp;
        $Kp = $config_Kp // $Kp;
        $Ki = $config_Ki // $Ki;
        $Kd = $config_Kd // $Kd;
        $min_fan_duty = $conf_min_fan_duty // $min_fan_duty;
        $max_fan_duty = $conf_max_fan_duty // $max_fan_duty;
        $sleep_interval = $conf_sleep_interval // $sleep_interval;
    }
}


# set fan control mode to "Optimal mode"
`ipmitool raw 0x30 0x45 0x01 2`;
sleep 1;


do {
    read_config();
    $datetime = build_date_time_string();

    ($max_gpu_temp, $avg_gpu_temp)  = get_gpu_temps();

    $gpu_temp = $max_gpu_temp;

    $error = $gpu_temp - $target_gpu_temp;
    $correction = calc_PID_correction($error, $error_old);
    $fan_duty += $correction;


    if ($fan_duty <= $min_fan_duty) {
        $fan_duty = $min_fan_duty;
    } elsif ($fan_duty >= $max_fan_duty) {
        $fan_duty = $max_fan_duty;
    }
    
    set_fan_duty($fan_duty);

    $power = get_power_reading();
    
    print_stats($gpu_temp, $power);
    
    $error_old = $error;

    sleep $sleep_interval;

} while ($sleep_interval)