## Lesson Calendar Tracking

Fairly custom scripts to connect to Google Calendar via OAUTH, calculate scheduled teaching lessons for time period, save views of data to SQLite, and email digest via Gmail to necesary parties.  

New Installation:
1.  Initialize SQLite DB by running:  `db/sqlite3 db/PrivateDatabase.db`.
2.  Load the database schema via `.read config/SchemaSetup.sql`
3.  Load the private student data via `.read config/PrivateClientData.sql` (if no 'PrivateClientData.sql' doesn't exist then create rows following pattern listed in 'config/SchemaSetup.sql')
4.  Use https://console.developers.google.com/flows/enableapi?apiid=calendar to allow OAUTH access:
  1.  Create project (and automatically enable if Calendar API) if none exists.
  2.  On Credentials page select 'Google Calendar API Quickstart' and save 'Client ID' and 'Client Secret' values.

Required Gems:
* `gem install 'google_calendar'` - https://github.com/northworld/google_calendar
* `gem install 'sqlite3'` '- https://github.com/sparklemotion/sqlite3-ruby
* `gem install 'google-api-client'` - https://developers.google.com/google-apps/calendar/quickstart/ruby

Run command (Cron command is saved in 'config/PrivateRunCommand.cron'):
`./src/LoadCalIntoSqlAndEmail.rb <<Gmail_Account_Name>> <<Gmail_Password>> <<Send_Email_To>> <<Calendar_Name>> <<Client_ID>> <<Client_Secret>> <<Refresh_Token>>`
On first run leave `<<Refresh_Token>>` parameter empty and follow script prompts to receive it.

