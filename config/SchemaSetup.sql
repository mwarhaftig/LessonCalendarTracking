CREATE TABLE IF NOT EXISTS Student
( id INTEGER,
  first_name VARCHAR NOT NULL,
  last_name VARCHAR,
  start_date REAL,
  address VARCHAR,
  CONSTRAINT student_pk PRIMARY KEY (id)
);

--- Copy lines & insert once per student.
--- INSERT INTO Student (first_name, last_name, start_date, address)
--- VALUES ('John', 'Doe', julianday('2014-01-14') , 'address');

CREATE TABLE IF NOT EXISTS Rate
( id INTEGER,
  student_id INTEGER NOT NULL,
  rate REAL NOT NULL,
  is_travel INTEGER,
  start_date REAL NOT NULL,
  end_date REAL,
  CONSTRAINT rate_pk PRIMARY KEY (id)
);

--- Copy lines & insert once per student's rate.
--- INSERT INTO Rate (student_id, rate, is_travel, created_date)
--- VALUES ((SELECT id FROM Student WHERE last_name='Doe'), '75.50', '0', julianday('now'));

CREATE TABLE IF NOT EXISTS Lesson
( id INTEGER,
  student_id INTEGER NOT NULL,
  rate_id INTEGER,
  rate INTEGER,
  start_time REAL NOT NULL,
  end_time REAL NOT NULL,
  CONSTRAINT lesson_pk PRIMARY KEY (id)
);

--- Create Lesson entry just for testing.
--- INSERT INTO Lesson (id, student_id, rate_id, rate, start_time, end_time)
--- VALUES (1, 1, 1, 34.00, julianday('now','start of day','-14 days'),  julianday('now','-14 days'));

CREATE INDEX IF NOT EXISTS lesson_start_time_idx ON Lesson (start_time);
CREATE INDEX IF NOT EXISTS lesson_end_time_idx ON Lesson (end_time);

CREATE TABLE IF NOT EXISTS Report_Time
( id INTEGER,
  run_time REAL,
  CONSTRAINT report_time_pk PRIMARY KEY (id)
);
CREATE INDEX IF NOT EXISTS report_time_run_time ON Report_Time (run_time);

DROP VIEW Lesson_Week_Details;
CREATE VIEW IF NOT EXISTS Lesson_Week_Details AS 
 SELECT s.first_name as name,count(*) as lessons, SUM(ROUND((l.end_time - l.start_time) * 24,2)) as hours, sum(r.rate * ROUND((l.end_time - l.start_time) * 24,2)) as pay
 FROM Lesson l JOIN Student s ON l.student_id = s.id
 JOIN Rate r ON r.student_id = s.id
 WHERE l.start_time > julianday('now', 'localtime', 'start of day', '-6 day')
 AND l.end_time <= julianday('now', 'localtime', 'start of day', '1 day')
 AND r.start_date <= l.start_time 
 AND (r.end_date IS NULL OR r.end_date > l.start_time)
 GROUP BY s.first_name
 ORDER BY hours DESC;

DROP VIEW Lesson_Week_Total;
CREATE VIEW IF NOT EXISTS Lesson_Week_Total AS
 SELECT count(*) as lessons, SUM(ROUND((l.end_time - l.start_time) * 24,2)) as hours, sum(r.rate * ROUND((l.end_time - l.start_time) * 24,2)) as pay
 FROM Lesson l JOIN Student s ON l.student_id = s.id
 JOIN Rate r ON r.student_id = s.id
 WHERE l.start_time > julianday('now', 'localtime', 'start of day', '-6 day')
 AND l.end_time <= julianday('now', 'localtime', 'start of day', '1 day')
 AND r.start_date <= l.start_time
 AND (r.end_date IS NULL OR r.end_date > l.start_time);

DROP VIEW Lesson_Prev_Week_Total;
CREATE VIEW IF NOT EXISTS Lesson_Prev_Week_Total AS 
 SELECT count(*) as lessons, SUM(ROUND((l.end_time - l.start_time) * 24,2)) as hours, sum(r.rate * ROUND((l.end_time - l.start_time) * 24,2)) as pay
 FROM Lesson l JOIN Student s ON l.student_id = s.id
 JOIN Rate r ON r.student_id = s.id
 WHERE l.start_time > julianday('now', 'localtime', 'start of day', '-13 day')
 AND l.end_time <= julianday('now', 'localtime', 'start of day', '-6 day')
 AND r.start_date <= l.start_time 
 AND (r.end_date IS NULL OR r.end_date > l.start_time);

DROP VIEW Lesson_30_Day_Total;
CREATE VIEW IF NOT EXISTS Lesson_30_Day_Total AS
 SELECT count(*) as lessons, SUM(ROUND((l.end_time - l.start_time) * 24,2)) as hours, sum(r.rate * ROUND((l.end_time - l.start_time) * 24,2)) as pay
 FROM Lesson l JOIN Student s ON l.student_id = s.id
 JOIN Rate r ON r.student_id = s.id
 WHERE l.start_time > julianday('now', 'localtime', 'start of day', '-29 day')
 AND l.end_time <= julianday('now', 'localtime', 'start of day', '1 day')
 AND r.start_date <= l.start_time 
 AND (r.end_date IS NULL OR r.end_date > l.start_time);
 
DROP VIEW Lesson_Prev_30_Day_Total;
 CREATE VIEW IF NOT EXISTS Lesson_Prev_30_Day_Total AS 
 SELECT count(*) as lessons, SUM(ROUND((l.end_time - l.start_time) * 24,2)) as hours, sum(r.rate * ROUND((l.end_time - l.start_time) * 24,2)) as pay
 FROM Lesson l JOIN Student s ON l.student_id = s.id
 JOIN Rate r ON r.student_id = s.id
 WHERE l.start_time > julianday('now', 'localtime', 'start of day', '-59 day')
 AND l.end_time <= julianday('now', 'localtime', 'start of day', '-29 day')
 AND r.start_date <= l.start_time
 AND (r.end_date IS NULL OR r.end_date > l.start_time);

DROP VIEW Lesson_YTD_Total;
CREATE VIEW IF NOT EXISTS Lesson_YTD_Total AS
 SELECT count(*) as lessons, SUM(ROUND((l.end_time - l.start_time) * 24,2)) as hours, sum(r.rate * ROUND((l.end_time - l.start_time) * 24,2)) as pay
 FROM Lesson l JOIN Student s ON l.student_id = s.id
 JOIN Rate r ON r.student_id = s.id
 WHERE l.start_time > julianday('now', 'localtime', 'start of year', 'start of day')
 AND l.end_time <= julianday('now', 'localtime', 'start of day', '1 day')
 AND r.start_date <= l.start_time
 AND (r.end_date IS NULL OR r.end_date > l.start_time);
 
DROP VIEW Lesson_Prev_YTD_Total;
CREATE VIEW IF NOT EXISTS Lesson_Prev_YTD_Total AS 
 SELECT count(*) as lessons, SUM(ROUND((l.end_time - l.start_time) * 24,2)) as hours, sum(r.rate * ROUND((l.end_time - l.start_time) * 24,2)) as pay
 FROM Lesson l JOIN Student s ON l.student_id = s.id
JOIN Rate r ON r.student_id = s.id
 WHERE l.start_time > julianday('now', 'localtime', 'start of year', '-1 year', 'start of day')
 AND l.end_time <= julianday('now', 'localtime', 'start of day', '-1 year', '1 day')
 AND r.start_date <= l.start_time
 AND (r.end_date IS NULL OR r.end_date > l.start_time);
