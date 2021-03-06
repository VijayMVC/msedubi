﻿
CREATE PROC dbo.LoadDateDimension
@Start datetime,
@End datetime
AS

DECLARE 
@StartDate AS DATETIME = @Start,
@EndDate AS DATETIME = @End,
@Date AS DATETIME,
@WDofMonth AS INT,
@CurrentMonth AS INT = 1,
@CurrentDate AS DATE = getdate(); 

DELETE FROM dbo.DimDate;

--IF YOU ARE USING THE YYYYMMDD format for the primary key then you need to comment out this line.
--DBCC CHECKIDENT (DimDate, RESEED, 60000) --In case you need to add earlier dates later.
DECLARE @tmpDOW TABLE (
DOW  INT,
Cntr INT); --Table for counting DOW occurance in a month

INSERT  INTO @tmpDOW (DOW, Cntr)
VALUES              (1, 0); --Used in the loop below

INSERT  INTO @tmpDOW (DOW, Cntr)
VALUES              (2, 0);

INSERT  INTO @tmpDOW (DOW, Cntr)
VALUES              (3, 0);
 
INSERT  INTO @tmpDOW (DOW, Cntr)
VALUES              (4, 0);

INSERT  INTO @tmpDOW (DOW, Cntr)
VALUES              (5, 0);

INSERT  INTO @tmpDOW (DOW, Cntr)
VALUES              (6, 0);

INSERT  INTO @tmpDOW (DOW, Cntr)
VALUES              (7, 0);

SET @Date = @StartDate;

WHILE @Date < @EndDate
 BEGIN
 IF DATEPART(MONTH, @Date) <> @CurrentMonth
 BEGIN
 SELECT @CurrentMonth = DATEPART(MONTH, @Date);
 UPDATE  @tmpDOW
 SET Cntr = 0;
 END
 UPDATE  @tmpDOW
 SET Cntr = Cntr + 1
 WHERE   DOW = DATEPART(DW, @DATE);
 SELECT @WDofMonth = Cntr
 FROM   @tmpDOW
 WHERE  DOW = DATEPART(DW, @DATE);

 INSERT INTO DimDate ([DateSK], [FullDate], [Day], [DayOfWeek], [DayOfWeekNumber], [DayOfWeekInMonth], [CalendarMonthNumber], [CalendarMonthName], [CalendarQuarterNumber], [CalendarQuarterName], [CalendarYearNumber], [StandardDate], [WeekDayFlag], [HolidayFlag], [OpenFlag], [FirstDayOfCalendarMonthFlag], [LastDayOfCalendarMonthFlag], HolidayText) --TO MAKE THE DateSK THE YYYYMMDD FORMAT UNCOMMENT THIS LINE… Comment for autoincrementing.
 SELECT CONVERT (VARCHAR, @Date, 112) AS [DateSK], --TO MAKE THE DateSK THE YYYYMMDD FORMAT UNCOMMENT THIS LINE COMMENT FOR AUTOINCREMENT
 @Date AS [FullDate],
 DATEPART(DAY, @DATE) AS [Day],
 CASE DATEPART(DW, @DATE)
 WHEN 1 THEN 'Sunday'
 WHEN 2 THEN 'Monday'
 WHEN 3 THEN 'Tuesday'
 WHEN 4 THEN 'Wednesday'
 WHEN 5 THEN 'Thursday'
 WHEN 6 THEN 'Friday'
 WHEN 7 THEN 'Saturday'
 END AS [DayOfWeek],
 DATEPART(DW, @DATE) AS [DayOfWeekNumber],
 @WDofMonth AS [DOWInMonth],
 DATEPART(MONTH, @DATE) AS [CalendarMonthNumber], --To be converted with leading zero later.
 DATENAME(MONTH, @DATE) AS [CalendarMonthName],
 DATEPART(qq, @DATE) AS [CalendarQuarterNumber], --Calendar quarter
 CASE DATEPART(qq, @DATE)
 WHEN 1 THEN 'First'
 WHEN 2 THEN 'Second'
 WHEN 3 THEN 'Third'
 WHEN 4 THEN 'Fourth'
 END AS [CalendarQuarterName],
 DATEPART(YEAR, @Date) AS [CalendarYearNumber],
 RIGHT('0' + CONVERT (VARCHAR (2), MONTH(@Date)), 2) + '/' + RIGHT('0' + CONVERT (VARCHAR (2), DAY(@Date)), 2) + '/' + CONVERT (VARCHAR (4), YEAR(@Date)),
 CASE DATEPART(DW, @DATE)
 WHEN 1 THEN 0
 WHEN 2 THEN 1
 WHEN 3 THEN 1
 WHEN 4 THEN 1
 WHEN 5 THEN 1
 WHEN 6 THEN 1
 WHEN 7 THEN 0
 END AS [WeekDayFlag],
 0 AS HolidayFlag,
 CASE DATEPART(DW, @DATE)
 WHEN 1 THEN 0
 WHEN 2 THEN 1
 WHEN 3 THEN 1
 WHEN 4 THEN 1
 WHEN 5 THEN 1
 WHEN 6 THEN 1
 WHEN 7 THEN 1
 END AS OpenFlag,
 CASE DATEPART(dd, @Date)
 WHEN 1 THEN 1 ELSE 0
 END AS [FirstDayOfCalendarMonthFlag],
 CASE
 WHEN DateAdd(day, -1, DateAdd(month, DateDiff(month, 0, @Date) + 1, 0)) = @Date THEN 1 ELSE 0
 END AS [LastDayOfCalendarMonthFlag],
 NULL AS HolidayText;
 SELECT @Date = DATEADD(dd, 1, @Date);
 END

 -- Add HOLIDAYS ————————————————————————————————————--
-- New Years Day ———————————————————————————————
 UPDATE  dbo.DimDate
 SET HolidayText = 'New Year”s Day',
 HolidayFlag = 1,
 OpenFlag    = 0
 WHERE   [CalendarMonthNumber] = 1
 AND [DAY] = 1;

--Set OpenFlag = 0 if New Year's Day is on weekend
 UPDATE  dbo.DimDate
 SET OpenFlag = 0
 WHERE   DateSK IN (SELECT CASE
 WHEN DayOfWeek = 'Sunday' THEN DATESK + 1
 END
 FROM   DimDate
 WHERE  CalendarMonthNumber = 1
 AND [DAY] = 1);

-- Martin Luther King Day —————————————————————————————
--Third Monday in January starting in 1983
 UPDATE  DimDate
 SET HolidayText = 'Martin Luther King Jr. Day',
 HolidayFlag = 1,
 OpenFlag    = 0
 WHERE   [CalendarMonthNumber] = 1 --January
 AND [Dayofweek] = 'Monday'
 AND CalendarYearNumber >= 1983 --When holiday was official
 AND [DayOfWeekInMonth] = 3; --Third X day of current month.

 --President's Day —————————————————————————————
 --Third Monday in February.
 UPDATE  DimDate
 SET HolidayText = 'President”s Day',
 HolidayFlag = 1,
 OpenFlag    = 0
 WHERE   [CalendarMonthNumber] = 2 --February
 AND [Dayofweek] = 'Monday'
 AND [DayOfWeekInMonth] = 3; --Third occurance of a monday in this month.

 --Memorial Day —————————————————————————————-
 --Last Monday in May
 UPDATE  dbo.DimDate
 SET HolidayText = 'Memorial Day',
 HolidayFlag = 1,
 OpenFlag    = 0
 FROM    DimDate
 WHERE   DateSK IN (SELECT   MAX([DateSK])
 FROM     dbo.DimDate
 WHERE    [CalendarMonthName] = 'May'
 AND [DayOfWeek] = 'Monday'
 GROUP BY CalendarYearNumber, [CalendarMonthNumber]);

--4th of July ———————————————————————————————
 UPDATE  dbo.DimDate
 SET HolidayText = 'Independance Day',
 HolidayFlag = 1,
 OpenFlag    = 0
 WHERE   [CalendarMonthNumber] = 7
 AND [DAY] = 4;

--Set OpenFlag = 0 if July 4th is on weekend
 UPDATE  dbo.DimDate
 SET OpenFlag = 0
 WHERE   DateSK IN (SELECT CASE
 WHEN DayOfWeek = 'Sunday' THEN DATESK + 1
 END
 FROM   DimDate
 WHERE  CalendarMonthNumber = 7
 AND [DAY] = 4);

--Labor Day ——————————————————————————————-
 --First Monday in September
 UPDATE  dbo.DimDate
 SET HolidayText = 'Labor Day',
 HolidayFlag = 1,
 OpenFlag    = 0
 FROM    DimDate
 WHERE   DateSK IN (SELECT   MIN([DateSK])
 FROM     dbo.DimDate
 WHERE    [CalendarMonthName] = 'September'
 AND [DayOfWeek] = 'Monday'
 GROUP BY CalendarYearNumber, [CalendarMonthNumber]);

--Columbus Day——————————————————————————————
--2nd Monday in October
 UPDATE  dbo.DimDate
 SET HolidayText = 'Columbus Day',
 HolidayFlag = 1,
 OpenFlag    = 0
 FROM    DimDate
 WHERE   DateSK IN (SELECT   MIN(DateSK)
 FROM     dbo.DimDate
 WHERE    [CalendarMonthName] = 'October'
 AND [DayOfWeek] = 'Monday'
 AND [DayOfWeekInMonth] = 2
 GROUP BY CalendarYearNumber, [CalendarMonthNumber]);

--Veteran's Day ————————————————————————————————————--
 UPDATE  DimDate
 SET HolidayText = 'Veteran”s Day',
 HolidayFlag = 1,
 OpenFlag    = 0
 WHERE   DateSK IN (SELECT CASE
 WHEN DayOfWeek = 'Saturday' THEN DateSK - 1
 WHEN DayOfWeek = 'Sunday' THEN DateSK + 1 ELSE DateSK
 END AS VeteransDateSK
 FROM   DimDate
 WHERE  [CalendarMonthNumber] = 11
 AND [DAY] = 11);

 --THANKSGIVING ————————————————————————————————————--
 --Fourth THURSDAY in November.
 UPDATE  DimDate
 SET HolidayText = 'Thanksgiving Day',
 HolidayFlag = 1,
 OpenFlag    = 0
 WHERE   [CalendarMonthNumber] = 11
 AND [DAYOFWEEK] = 'Thursday'
 AND [DayOfWeekInMonth] = 4;

 --CHRISTMAS ——————————————————————————————-
 UPDATE  dbo.DimDate
 SET HolidayText = 'Christmas Day',
 HolidayFlag = 1,
 OpenFlag    = 0
 WHERE   [CalendarMonthNumber] = 12
 AND [DAY] = 25;

--Set OpenFlag = 0 if Christmas on weekend
 UPDATE  dbo.DimDate
 SET OpenFlag = 0
 WHERE   DateSK IN (SELECT CASE
 WHEN DayOfWeek = 'Sunday' THEN DATESK + 1
 WHEN Dayofweek = 'Saturday' THEN DateSK - 1
 END
 FROM   DimDate
 WHERE  CalendarMonthNumber = 12
 AND DAY = 25);

-- Valentine's Day
 UPDATE  dbo.DimDate
 SET HolidayText = 'Valentine''s Day'
 WHERE   CalendarMonthNumber = 2
 AND [DAY] = 14;

-- Saint Patrick's Day
 UPDATE  dbo.DimDate
 SET HolidayText = 'Saint Patrick''s Day'
 WHERE   [CalendarMonthNumber] = 3
 AND [DAY] = 17;

 --Mother's Day —————————————————————————————
 --Second Sunday of May
 UPDATE  DimDate
 SET HolidayText = 'Mother''s Day' --select * from DimDate
 WHERE   [CalendarMonthNumber] = 5 --May
 AND [Dayofweek] = 'Sunday'
 AND [DayOfWeekInMonth] = 2; --Second occurance of a monday in this month.

 --Father's Day —————————————————————————————
 --Third Sunday of June
 UPDATE  DimDate
 SET HolidayText = 'Father''s Day' --select * from DimDate
 WHERE   [CalendarMonthNumber] = 6 --June
 AND [Dayofweek] = 'Sunday'
 AND [DayOfWeekInMonth] = 3; --Third occurance of a monday in this month.

 --Halloween 10/31 ———————————————————————————-
 UPDATE  dbo.DimDate
 SET HolidayText = 'Halloween'
 WHERE   [CalendarMonthNumber] = 10
 AND [DAY] = 31;

-- Election Day————————————————————————————--
-- The first Tuesday after the first Monday in November.
 BEGIN TRY
 DROP TABLE #tmpHoliday;
 END TRY
 BEGIN CATCH
 --do nothing
 END CATCH

CREATE TABLE #tmpHoliday
 (
 ID     INT      IDENTITY (1, 1),
 DateID INT     ,
 Week   TINYINT ,
 YEAR   CHAR (4),
 DAY    CHAR (2)
 );

INSERT INTO #tmpHoliday (DateID, [YEAR], [DAY])
 SELECT   [DateSK],
 CalendarYearNumber,
 [DAY]
 FROM     dbo.DimDate
 WHERE    [CalendarMonthNumber] = 11
 AND [Dayofweek] = 'Monday'
 ORDER BY CalendarYearNumber, [DAY];

DECLARE @CNTR AS INT,
 @POS AS INT,
 @STARTYEAR AS INT,
 @ENDYEAR AS INT,
 @CURRENTYEAR AS INT,
 @MINDAY AS INT;

SELECT @CURRENTYEAR = MIN([YEAR]),
 @STARTYEAR = MIN([YEAR]),
 @ENDYEAR = MAX([YEAR])
 FROM   #tmpHoliday;

WHILE @CURRENTYEAR <= @ENDYEAR
 BEGIN
 SELECT @CNTR = COUNT([YEAR])
 FROM   #tmpHoliday
 WHERE  [YEAR] = @CURRENTYEAR;
 SET @POS = 1;
 WHILE @POS <= @CNTR
 BEGIN
 SELECT @MINDAY = MIN(DAY)
 FROM   #tmpHoliday
 WHERE  [YEAR] = @CURRENTYEAR
 AND [WEEK] IS NULL;
 UPDATE  #tmpHoliday
 SET [WEEK] = @POS
 WHERE   [YEAR] = @CURRENTYEAR
 AND [DAY] = @MINDAY;
 SELECT @POS = @POS + 1;
 END
 SELECT @CURRENTYEAR = @CURRENTYEAR + 1;
 END

UPDATE  DT
 SET HolidayText = 'Election Day'
 FROM    dbo.DimDate AS DT
 INNER JOIN
 #tmpHoliday AS HL
 ON (HL.DateID + 1) = DT.DateSK
 WHERE   [WEEK] = 1;

DROP TABLE #tmpHoliday;

UPDATE d
SET
	d.Term = t.Term,
	d.TermNumber = t.TermNumber,
	d.SchoolYear = t.SchoolYear,
	d.TermAK = t.TermAK
FROM DimDate d
LEFT OUTER JOIN HigherED_Staging.dbo.Term t
	ON d.fullDate between t.StartDate  and t.EndDate

/* Insert default date row */
INSERT INTO DimDate ([DateSK], [FullDate], [Day], [DayOfWeek], [DayOfWeekNumber], [DayOfWeekInMonth], [CalendarMonthNumber], [CalendarMonthName], [CalendarQuarterNumber], [CalendarQuarterName], [CalendarYearNumber], [StandardDate], [WeekDayFlag], [HolidayFlag], [OpenFlag], [FirstDayOfCalendarMonthFlag], [LastDayOfCalendarMonthFlag], HolidayText)
SELECT TOP 1  19000101,'1/1/1900',  Day, DayOfWeek, DayOfWeekNumber, DayOfWeekInMonth, CalendarMonthNumber, CalendarMonthName, CalendarQuarterNumber, CalendarQuarterName, CalendarYearNumber, '1/1/1900', WeekDayFlag, HolidayFlag, OpenFlag, FirstDayOfCalendarMonthFlag, LastDayOfCalendarMonthFlag, HolidayText
FROM DimDate
WHERE dayofweek = 'monday';