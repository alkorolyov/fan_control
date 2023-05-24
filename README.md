# fan_control
Simple Perl script to control FAN speed depending on GPU temp

Change config.ini file to set up limits.

For the moment changes only periferal zone (1). In order to control both 
zones (CPU and Periferal) enter standard mode and uncomment this line:
`ipmitool raw 0x30 0x70 0x66 0x01 0 $new_fan_duty`;

# check cron service
systemctl status cron
# edit cron jobs
sudo crontab -e
# add new line (run at each reboot):
@reboot perl /home/ergot/fan_control/fan_control.pl > /home/ergot/fan_control/fan_control.log
# check running jobs:
sudo crontab -l
# reboot to start the script
sudo reboot now


