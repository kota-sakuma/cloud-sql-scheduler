# cloud-sql-scheduler

This is a simple scheduler for Google Cloud SQL instances. It can be used to start and stop instances on a schedule.

## Quickstart
Ensure you have the following environment variables set:

| Variable        | Description                                                                                                                 | Default                               |
|:----------------|:----------------------------------------------------------------------------------------------------------------------------|:--------------------------------------|
| PROJECT_ID      | The Google Cloud project ID                                                                                                 | -                                     |
| REGION          | The region where resources are deployed to.                                                                                 | asia-northeast1                       |
| TIMEZONE        | The timezone to use for scheduling.                                                                                         | Asia/Tokyo                            |
| INSTANCES       | The name of Cloud SQL instances to start/stop.<br>Multiple instances can be separated by a comma.<br>e.g. `mysql-1,mysql-2` | -                                     |
| START_SCHEDULE  | The schedule to start instances.<br> The format should be the cron format.                                                  | `0 9 * * 1-5`<br># 9:00 AM, Mon-Fri   |
| STOP_SCHEDULE   | The schedule to stop instances.<br> The format should be the cron format.                                                                                             | `0 18 * * 1-5`<br># 6:00 PM, Mon-Fri  |

To deploy the scheduler, run the following command:
```bash
git clone https://github.com/kota-sakuma/cloud-sql-scheduler.git
cd cloud-sql-scheduler
chmod +x main.sh
./main.sh deploy
```

To remove the scheduler, run the following command:
```bash
./main.sh delete
```
