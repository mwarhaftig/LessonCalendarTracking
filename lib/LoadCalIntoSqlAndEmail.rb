#!/usr/bin/ruby

# Script to gather events from google calendar API, load into SQLite Database and email results.
require 'net/smtp'
require 'sqlite3'
require 'rubygems'
require 'date'
require 'google_calendar'

def formatSchedulingIssue(event, issue)
    return "<tr><td>#{event.title}</td><td>" + Time.parse(event.start_time).localtime.strftime("%Y-%m-%d %H:%M") + "</td><td>" +
    Time.parse(event.end_time).localtime.strftime("%Y-%m-%d %H:%M") + "</td><td>" + issue + "</td></tr>"
end

def cal_events_to_db (periodStartTime = (Time.new(Time.now.year, Time.now.month, Time.now.day, 0, 0, 0) - (30 *60 * 60 *24)).utc,
                      periodEndTime = (Time.new(Time.now.year, Time.now.month, Time.now.day, 0, 0, 0) + (60 * 60 *24)).utc, maxResults = 400)
    puts "Finding calendar events for #{periodStartTime} - #{periodEndTime}."
    schedulingIssues = ""
  
    # Calendar setup
    cal = Google::Calendar.new(:client_id     => @clientID,
                             :client_secret => @clientSecret,
                             :calendar      => @calName,
                             :redirect_url  => "urn:ietf:wg:oauth:2.0:oob"
                             )
                             
    if @refreshToken.nil? || @refreshToken == ""
            # A user needs to approve access in order to work with their calendars.
            puts "Visit the following web page in your browser and approve access in order to get a refresh_token:"
            puts cal.authorize_url
            exit
    end
        
    cal.login_with_refresh_token(@refreshToken)

    events = cal.find_events_in_range(periodStartTime.localtime, periodEndTime.localtime, { :max_results => "#{maxResults}" } )
    puts "Found #{events.size} events in calendar for time range."
    
    @db.execute("DELETE FROM Lesson WHERE start_time >= ? AND end_time <= ?",
                DateTime.parse(periodStartTime.to_s).jd, DateTime.parse(periodEndTime.to_s).jd)

    lessonsCreated = 0;
    events.each do |event|
        eventTitle = /(no)*\s*(\w*)\s*(.*?)\s*lesson.*/i.match(event.title)

        next if eventTitle.nil?
        next if !eventTitle[1].nil? # Skip event if event has "No" prefix.
        
        # Get student_id from event title's name.
        findStudent = "SELECT id FROM Student WHERE lower(first_name) = ?"
        findStudent = findStudent + " AND lower(last_name) = ?" if eventTitle[3] != ""
        studentId = (eventTitle[3] == "") ? (@db.execute(findStudent,eventTitle[2].downcase)) :
        (@db.execute(findStudent, eventTitle[2].downcase, eventTitle[3].downcase))

        # If no student_id populate error table.
        if ((studentId.nil?) || (studentId.empty?))
            schedulingIssues = schedulingIssues + formatSchedulingIssue(event, "Could not find student name for this lesson.")
            next
        end
        
        # If more than 1 student_id found then populate error table.
        schedulingIssues = schedulingIssues + formatSchedulingIssue(event, "Found multiple students for this lesson.") if !studentId[1].nil?
        next if !studentId[1].nil?
        
        rateId = @db.execute("SELECT id FROM rate WHERE student_id = ? and start_date <= ? AND (end_date > ? OR end_date IS NULL)", studentId[0][0], DateTime.parse(event.start_time).jd, DateTime.parse(event.end_time).jd)

        # If no rate_id populate error table.
        if ((rateId.nil?) || (rateId.empty?))
            schedulingIssues = schedulingIssues + formatSchedulingIssue(event, "Could not find rate for this lesson.")
            next
        end

        # If more than 1 rate_id found then populate error table.
        schedulingIssues = schedulingIssues + formatSchedulingIssue(event, "Found multiple rates for this lesson.") if !rateId[1].nil?
        next if !rateId[1].nil?

        @db.execute("INSERT INTO Lesson (student_id, start_time, end_time, rate_id) VALUES (?, julianday(?), julianday(?), ?)",
                    studentId[0][0], event.start_time.to_s, event.end_time.to_s, rateId[0][0])
        lessonsCreated = lessonsCreated + 1

    end
    puts "Created #{lessonsCreated} lessons for this time range."
    return schedulingIssues
    
end

def comma_numbers(number, delimiter = ',')
    number.to_s.reverse.gsub(%r{([0-9]{3}(?=([0-9]{1})))}, "\\1#{delimiter}").reverse
end

# Save input parameters.
username = ARGV[0]
password = ARGV[1]
sendTo = ARGV[2].split(",")
@calName = ARGV[3]
@clientID = ARGV[4]
@clientSecret = ARGV[5]
@refreshToken = ARGV[6]

puts "Creating DB connection."
@db = SQLite3::Database.new File.expand_path(File.dirname(__FILE__)) + "/../db/PrivateDatabase.db"

# Don't run if that already has been run today.
hasRunToday = @db.execute("SELECT id FROM Report_Time WHERE run_time = ?", DateTime.now.jd)
if ((!hasRunToday.nil?) && (!hasRunToday[0].nil?))
    puts "Script has already run today.  Skipping."
    exit
end

# Call to load calendar events into database.
schedulingIssues = cal_events_to_db

puts "Getting database views data."
weekDetail = ""
@db.execute( "SELECT name,lessons,hours,pay FROM Lesson_Week_Details" ) do |name,lessons,hours,pay|
    next if lessons == 0
    weekDetail = "#{weekDetail}<tr><td>#{name}</td><td>#{lessons}</td><td>#{hours}</td><td>" +  comma_numbers(sprintf('$%.2f', pay)) + "</td></tr>"
end

weekTotalSum = ""
@db.execute( "SELECT lessons,hours,pay FROM Lesson_Week_Total" ) do |lessons,hours,pay|
    weekTotalSum = "#{weekTotalSum}<tr><td>TOTAL</td><td>0</td><td>0.0</td><td>$0</td></tr>" if lessons == 0
    next if lessons == 0
    weekTotalSum = "#{weekTotalSum}<tr><td>TOTAL</td><td>#{lessons}</td><td>#{hours}</td><td>" + comma_numbers(sprintf('$%.2f', pay)) + "</td></tr>"
end

studentsOver2YearsAtRate = ""
@db.execute( "SELECT name,days_at_rate FROM Student_Over_2_Years_At_Current_Rate" ) do |name,days_at_rate|
    yearsAtRate = days_at_rate.round / 365
    monthsAtRate = (days_at_rate.round % 365) / 30
    studentsOver2YearsAtRate = "<tr><td>#{name}</td><td>#{yearsAtRate} years #{monthsAtRate} months</td></tr>"
end

weekTotal = @db.execute( "SELECT lessons,hours,pay FROM Lesson_Week_Total" )
weekTotal[0] = ["0", "0", "0"] if weekTotal[0][1].nil?
prevWeekTotal = @db.execute( "select lessons,hours,pay FROM Lesson_Prev_Week_Total" )
prevWeekTotal[0] = ["0", "0", "0"] if prevWeekTotal[0][1].nil?

monthTotal = @db.execute( "SELECT lessons,hours,pay FROM Lesson_30_Day_Total" )
monthTotal[0] = ["0", "0", "0"] if monthTotal[0][1].nil?
prevMonthTotal = @db.execute( "SELECT lessons,hours,pay FROM Lesson_Prev_30_Day_Total" )
prevMonthTotal[0] = ["0", "0", "0"] if prevMonthTotal[0][1].nil?

ytdTotal = @db.execute( "SELECT lessons,hours,pay FROM Lesson_YTD_Total" )
ytdTotal[0] = ["0", "0", "0"] if ytdTotal[0][1].nil?
prevYtdTotal = @db.execute( "SELECT lessons,hours,pay FROM Lesson_Prev_YTD_Total" )
prevYtdTotal[0] = ["0", "0", "0"] if prevYtdTotal[0][1].nil?

histLessons = "<tr><th>Lessons</th><td>#{weekTotal[0][0]}</td><td>#{prevWeekTotal[0][0]}</td><td>#{monthTotal[0][0]}</td><td>#{prevMonthTotal[0][0]}</td><td>#{ytdTotal[0][0]}</td><td>#{prevYtdTotal[0][0]}</td></tr>"
histHours = "<tr><th>Hours</th><td>" + comma_numbers(sprintf('%.1f',weekTotal[0][1])) + "</td><td>" + comma_numbers(sprintf('%.1f',prevWeekTotal[0][1])) + "</td><td>" + comma_numbers(sprintf('%.1f',monthTotal[0][1])) + "</td><td>" + comma_numbers(sprintf('%.1f',prevMonthTotal[0][1])) + "</td><td>" + comma_numbers(sprintf('%.1f',ytdTotal[0][1])) + "</td><td>" + comma_numbers(sprintf('%.1f',prevYtdTotal[0][1])) + "</td></tr>"
histPay = "<tr><th>Pay</th><td>" + comma_numbers(sprintf('$%.2f',weekTotal[0][2])) + "</td><td>" + comma_numbers(sprintf('$%.2f',prevWeekTotal[0][2])) + "</td><td>" + comma_numbers(sprintf('$%.2f',monthTotal[0][2])) + "</td><td>" + comma_numbers(sprintf('$%.2f',prevMonthTotal[0][2])) + "</td><td>" + comma_numbers(sprintf('$%.2f',ytdTotal[0][2])) + "</td><td>" + comma_numbers(sprintf('$%.2f',prevYtdTotal[0][2])) + "</td></tr>"

schedIssTable = ""
if schedulingIssues != ""
    schedIssTable = "<h3>Scheduling Issues</h3><table id=\"vertNoTotal\" width=\"550\"><tr><th>Scheduling Item</th><th>Start Time</th><th>End Time</th><th>Issue</th><tr>#{schedulingIssues}</table>"
end

if studentsOver2YearsAtRate != ""
    studentsOver2YearsAtRate = "<h3>Students Paying Same Rate For Over Two Years</h3><table id=\"vertNoTotal\" width=\"550\"><tr><th>Student</th><th>Time At Same Rate</th><tr>#{studentsOver2YearsAtRate}</table>"
end

puts "Creating email."
message = <<MESSAGE_END
From: Lesson Tracker <LessonTracker>
To:  Lesson Tracker <LessonTracker>
MIME-Version: 1.0
Content-type: text/html
Subject: Teaching Summary - #{Time.now().strftime("%Y-%m-%d")}

<style>
 
table, td, th {
    border: 0px;
    border-collapse: collapse;
    padding: 6px;
    text-align: center;
}

table th {
    background-color: #0099ff;
    color: white;
}

table#vertNoTotal tr:nth-child(even) {
background-color: #eee;
}
table#vertNoTotal tr:nth-child(odd) {
background-color: #fff;
}

table#vert tr:nth-child(even) {
    background-color: #eee;
}
table#vert tr:nth-child(odd) {
   background-color: #fff;
}
table#vert tr:last-child {
   background-color: #eee;
   font-weight: bold;
}

table#horiz td:nth-child(n + 2):nth-child(-n + 3) {
    background-color: #eee;
}

table#horiz td:nth-child(n + 6):nth-child(-n + 7) {
    background-color: #eee;
}

table#horiz td:nth-child(odd) {
    color: grey;
}

table#horiz td:nth-child(even) {
    font-weight: bold;
}

</style>
<h3>Historical Summary</h3>
<table id="horiz" width="550">
<tr><td/><th>Week</th><th>Prev Week</th><th>30 Days</th><th>Prev 30</th><th>Year-To-Date</th><th>Prev YTD</th></tr>
#{histLessons}
#{histHours}
#{histPay}
</table>
<br>
<h3>Last Week's Summary</h3>
<table id="vert" width="350">
<tr><th>Student</th><th>Lessons</th><th>Hours</th><th>Pay</th></tr>
#{weekDetail}
#{weekTotalSum}
</table>
<br>
#{studentsOver2YearsAtRate}
<br>
#{schedIssTable}

MESSAGE_END

puts "Sending email."
smtp = Net::SMTP.new 'smtp.gmail.com', 587
smtp.enable_starttls
smtp.start("YourDomain", "#{username}@gmail.com", password, :login) do
        smtp.send_message(message, "lessontracker", sendTo )

puts "Creating Report_Time entry to prevent rerunning today."
@db.execute("INSERT INTO Report_Time (run_time) VALUES (?)", DateTime.now.jd)

puts "Done."
end
