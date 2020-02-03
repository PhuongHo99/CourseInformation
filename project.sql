USE [master]
GO

DROP DATABASE IF EXISTS [CourseInformation]
GO

CREATE DATABASE [CourseInformation]
GO

USE [CourseInformation]
GO
--========================================= Tables
CREATE TABLE [Student](
	studentId		INT			PRIMARY KEY		IDENTITY	NOT NULL,
	firstName		VARCHAR(200)	NOT NULL,
	lastName		VARCHAR(200)	NOT NULL,
	creditEarned	INT				NOT NULL,
	class			VARCHAR(50)		NOT NULL,
	isHonorStudent	BIT				NOT NULL,
	email			NVARCHAR(200),
	GPA				FLOAT			NOT NULL	
)
GO

CREATE TABLE [Department](
	departmentId			INT				PRIMARY KEY		IDENTITY			NOT NULL,
	departmentName			VARCHAR(200)										NOT NULL,
	location				VARCHAR(200)										NOT NULL,
	departmentChairId		INT													NOT NULL,
	phone					VARCHAR(50)
) 
GO

CREATE TABLE [Professor](
	professorId			INT				PRIMARY KEY		IDENTITY				NOT NULL,
	firstName			VARCHAR(200)											NOT NULL,
	lastName			VARCHAR(200)											NOT NULL,
	departmentId		INT				REFERENCES Department(departmentId)		NOT NULL,
	office				VARCHAR(100)											NOT NULL,
	phone				VARCHAR(50),
	email				VARCHAR(100)									

)
GO

CREATE TABLE [Course](
	courseId			INT				PRIMARY KEY		IDENTITY				NOT NULL,
	name				VARCHAR(200)											NOT NULL,
	professorId			INT				REFERENCES Professor(professorId)		NOT NULL,
	creditHour			INT														NOT NULL,
	departmentId		INT				REFERENCES Department(departmentId)		NOT NULL,
	location			VARCHAR(200)											NOT NULL,
	capacity			INT														NOT NULL
)
GO

CREATE TABLE [CourseStudent](
	courseId				INT		REFERENCES Course(courseId)	NOT NULL,
	studentId				INT		REFERENCES Student(studentId)	NOT NULL,
	PRIMARY KEY(courseId, studentId)
)
GO


--========================================= Insert Data
BULK INSERT [Student]
FROM 'c:\temp\student.txt'
WITH(
	FIRSTROW = 2,
	FIELDTERMINATOR ='\t',
	ROWTERMINATOR = '\n',
	TABLOCK,
	KEEPIDENTITY
)
GO


BULK INSERT [Department]
FROM 'c:\temp\department.txt'
WITH(
	FIRSTROW = 2,
	FIELDTERMINATOR ='\t',
	ROWTERMINATOR = '\n',
	TABLOCK,
	KEEPIDENTITY
)
GO

BULK INSERT [Professor]
FROM 'c:\temp\professor.txt'
WITH(
	FIRSTROW = 2,
	FIELDTERMINATOR ='\t',
	ROWTERMINATOR = '\n',
	TABLOCK,
	KEEPIDENTITY
)
GO

BULK INSERT [Course]
FROM 'c:\temp\course.txt'
WITH(
	FIRSTROW = 2,
	FIELDTERMINATOR ='\t',
	ROWTERMINATOR = '\n',
	TABLOCK,
	KEEPIDENTITY
)
GO

BULK INSERT [CourseStudent]
FROM 'c:\temp\courseAndStudent.txt'
WITH(
	FIRSTROW = 2,
	FIELDTERMINATOR ='\t',
	ROWTERMINATOR = '\n',
	TABLOCK,
	KEEPIDENTITY
)
GO

--=========================================Create  Error Tracking Tables

--==========Create a table that stores errors caused in Stored Procedures 

CREATE TABLE [dbo].[errors] (
    [errorId]             INT            IDENTITY (1, 1) NOT NULL,
    [ERROR_MESSAGE]       VARCHAR (500)  DEFAULT ('?') NOT NULL,
    [ERROR_LINE]          INT            NULL,
    [ERROR_NUMBER]        INT            NULL,
    [ERROR_PROCEDURE]     VARCHAR (100)  DEFAULT ('?') NOT NULL,
    [ERROR_SEVERITY]      INT            NULL,
    [ERROR_STATE]         INT            NULL,
    [DateTimeOfError]     DATETIME       DEFAULT (getdate()) NOT NULL,
    [Data]                NVARCHAR (MAX) NULL,
    [Resolved]            BIT            DEFAULT ((0)) NOT NULL,
    [ResolvedDescription] VARCHAR (8000) DEFAULT ('') NOT NULL,
    [ResolvedOn]          DATETIME       NULL,
    PRIMARY KEY CLUSTERED ([errorId] ASC)
);
GO

/* Create a Stored Procedure records an error */

CREATE PROCEDURE spRecordError
	@data nvarchar(max) = ''
AS
BEGIN
		BEGIN TRY
			INSERT INTO errors (
					ERROR_MESSAGE,		ERROR_LINE,
					ERROR_NUMBER,		ERROR_PROCEDURE,
					ERROR_SEVERITY,		ERROR_STATE,		Data)
			VALUES (ERROR_MESSAGE(),	ERROR_LINE(),
					ERROR_NUMBER(),		ERROR_PROCEDURE(),
					ERROR_SEVERITY(),	ERROR_STATE(),		@data)
		END TRY BEGIN CATCH 
			INSERT INTO errors (
					ERROR_MESSAGE,		ERROR_LINE,
					ERROR_NUMBER,		ERROR_PROCEDURE,
					ERROR_SEVERITY,		ERROR_STATE)
			VALUES (ERROR_MESSAGE(),	ERROR_LINE(),
					ERROR_NUMBER(),		ERROR_PROCEDURE(),
					ERROR_SEVERITY(),	ERROR_STATE())
		END CATCH
END
GO

--========================================= Views

CREATE VIEW [vwAllInformation]
AS 
SELECT s.*, c.*, d1.departmentName AS courseDepartment, p.firstName AS proFirstName, p.lastName AS proLastName, p.email AS proEmail, p.office, p.phone AS ProPhone, d2.departmentId AS proDepartment
FROM Student s
	JOIN CourseStudent cs ON cs.studentId = s.studentId 
	JOIN Course c ON c.courseId = cs.courseId
	JOIN Professor p ON p.professorId = c.professorId
	JOIN Department d1 ON d1.departmentId = c.departmentId
	JOIN Department d2 ON d2.departmentId = p.departmentId
GO

--=========================================Stored Procedures


--=========================================Rebuild and reorganize the table indexes to retrieve the data faster
CREATE PROCEDURE [dbo].[spRebuildReorgIndexList]
AS
	BEGIN
		DECLARE @tblName VARCHAR(50)

		DECLARE tblCursor CURSOR FOR (
			SELECT TABLE_NAME
			FROM INFORMATION_SCHEMA.TABLES
			WHERE TABLE_TYPE = 'BASE TABLE'
		)

		OPEN tblCursor

		FETCH NEXT FROM tblCursor INTO @tblName

		WHILE @@FETCH_STATUS = 0 BEGIN
			PRINT 'Indexing table: ' + @tblName
			EXEC ('ALTER INDEX ALL ON ' + @tblName + ' REORGANIZE')
			EXEC ('ALTER INDEX ALL ON ' + @tblName + ' REBUILD')
			FETCH NEXT FROM tblCursor INTO @tblName
		END

		CLOSE tblCursor
		DEALLOCATE tblCursor
	END
GO


--===================Get Student ID and Fullname By CourseID
CREATE PROCEDURE [spGetStudentByCourseId]
	@courseId INT
AS
	SET NOCOUNT ON 

	SELECT studentId, [fullName] = firstName + ' ' + lastName
	FROM vwAllInformation
	WHERE courseId = @courseId
GO

--===================Get Course Information Taken By Student ID
CREATE PROCEDURE [spGetCourseByStudentId]
	@studentId INT
AS
	SET NOCOUNT ON 

	SELECT courseId, name, location, [ProfessorName] = proFirstName + ' ' + proLastName
	FROM vwAllInformation
	WHERE studentId = @studentId
GO

--===================Get Honor Student List
CREATE PROCEDURE [spGetHonorStudent]
AS
	SELECT studentId, [fullName] = firstName + ' ' + lastName, GPA, class, ISNULL(email, 'Will be Updated')
	FROM Student 
	WHERE isHonorStudent =1
GO

--===================Get Student ID, Name, GPA, class Under a Certain GPA
CREATE PROCEDURE [spGetStudentUnderCertainGPA]
	@setGPA FLOAT
AS
	SELECT studentId, [fullName] = firstName + ' ' + lastName, GPA, class
	FROM Student 
	WHERE GPA < @setGPA
GO

--======================================Get Professor Has No Email
CREATE PROCEDURE [spGetProfessorNoEmail]
AS
 SELECT p.professorId,[Name] = p.firstName +' ' + p.lastName, d.departmentName
 FROM professor p	
	JOIN Department d ON p.departmentId = d.departmentId
 WHERE p.email IS NULL
GO

--======================================Get Number of courses taught by given professor
CREATE PROCEDURE [spGetCountByProfessorCourse]
 @professorId INT
AS
 SET NOCOUNT ON
 SELECT professorId, COUNT(*) AS NumOfCourses
 FROM Course
 WHERE professorId = @professorId
 GROUP BY professorId
 GO

 --====================================== Get total number of students in a specific course
CREATE PROCEDURE [spGetNumberofStudentsByCourseId]
	 @courseId INT
AS
	 SET NOCOUNT ON
	 SELECT courseId, name, COUNT(*) AS NumOfStudents
	 FROM vwAllInformation
	 WHERE courseId = @courseId
	 GROUP BY courseId,name
GO

--=========================================Get the number of students in certain course
CREATE PROCEDURE [spGetHonorStudentByCourseId]
	 @courseId INT
AS
	 SET NOCOUNT ON
	 SELECT courseId, name, COUNT(*) AS NumOfStudents
	 FROM vwAllInformation
	 WHERE courseId = @courseId AND isHonorStudent = 1
	 GROUP BY courseId,name
GO



--=========================================List all the professors in certain department who doesn’t have a phone number
CREATE PROCEDURE [spGetProfessorNoPhoneByDepartmentId]
	 @departmentId INT
AS
	 SET NOCOUNT ON
	 SELECT professorId, [FullName]= firstName+' '+ lastName,email
	 FROM Professor
	 WHERE departmentId = @departmentId AND phone IS NULL
	 ORDER BY [FullName]
GO


--=========================================Get a list of students that are not registered in any classes
CREATE PROCEDURE [spGetStudentInNoCourse]
AS
	 SET NOCOUNT ON
	 SELECT *
	 FROM Student
	 WHERE studentId NOT IN (SELECT DISTINCT studentId FROM vwAllInformation)
	 ORDER BY studentId
GO

--========================================= Get a list of professors that are not teaching any classes
CREATE PROCEDURE [spGetProfessorWithNoCourses]
AS
	 SET NOCOUNT ON
	SELECT *
	 FROM Professor
	 WHERE professorId NOT IN (SELECT DISTINCT studentId FROM vwAllInformation)
	 ORDER BY professorId
GO

--========================================Get a list of students that are taught by a specific professor.
CREATE PROCEDURE [spGetStudentByProfessorId]
	 @professorId INT
AS
	 SET NOCOUNT ON
	 SELECT studentId, [FullName] = firstName +' '+lastName, email
	 FROM vwAllInformation
	 WHERE professorId = @professorId
GO

--=========================================Get a list of courses where the capacity is not full
CREATE PROCEDURE [spCourseNotFullCpacity]
AS
	 SET NOCOUNT ON
	 SELECT courseId, name, capacity, capacity - COUNT(*) AS NumOfEmptySpaces
	 FROM vwAllInformation
	 GROUP BY courseId,name, capacity
	 HAVING capacity - COUNT(*) > 0
	 ORDER BY NumOfEmptySpaces
GO

--=========================================Get a list of professors with locations different from their deprartments' locations
CREATE PROCEDURE [spGetProfessorHavingDifferentLocation]
AS
	 SET NOCOUNT ON
	 SELECT professorId,  [FullName] = firstName +' '+lastName, 
			[ProfessorOffice]=p.office, 
			[DepartmentLocation]=d.location 
	 FROM Professor p
	 JOIN Department d ON p.departmentId= d.departmentId
	 WHERE p.office NOT LIKE d.location +'%'
	
GO

--=========================================Get a list of students taking multiple courses of the same professor
CREATE PROCEDURE [spGetStudentsTakingMultiCourseSameProfessor]
	@studentId int = 0
AS
	SET NOCOUNT ON
	SELECT cs.studentId, c.professorId, count(*) AS courses
	FROM CourseStudent cs
	JOIN Course c ON c.courseId = cs.courseId
	GROUP BY cs.studentId, c.professorId
	HAVING (count(*) > 1) AND (cs.studentId = @studentId OR @studentId = 0)
GO

--=========================================Get a list of students who's gpa is greater than 3.0
--=========================================and taking multiple courses of the same department
CREATE PROCEDURE [spGetStudentsGpaGreaterSameDepartment]
	@studentId int = 0
AS
	SET NOCOUNT ON
	SELECT DISTINCT cs.studentId, s.GPA, count(*) AS NumOfCourses
	FROM CourseStudent cs
	JOIN Course c ON c.courseId = cs.courseId
	JOIN Student s ON S.studentId = cs.studentId
	JOIN Department d ON d.departmentId = c.departmentId
	GROUP BY cs.studentId, d.departmentName, s.GPA
	HAVING (count(*) > 1) AND (cs.studentId = @studentId OR @studentId = 0) AND s.GPA > 3.0
GO

--========================================Return a list of Students who taks multiple course
--========================================in multiple departments. Also, if their GPA is below 2.0,
--======================================== return "F"(2.0 ~2.5 return"D", 2.5~3.0 return "C",3.0~3.5 return"B"
--========================================3.5~4.0 return"A")
CREATE PROCEDURE [spGetStudentScriptTakingMultipleCourses]
AS
 SET NOCOUNT ON
 SELECT cs.studentId,
 [Script] = (
  SELECT [ScriptType] =
 CASE
  WHEN s.GPA < 2.0 THEN 'F'
  WHEN s.GPA >=2.0 AND s.GPA <2.5 THEN 'D'
  WHEN s.GPA >=2.5 AND s.GPA <3.0 THEN 'C'
  WHEN s.GPA >=3.0 AND s.GPA <3.5 THEN 'B'
  ELSE 'A'
 END
 FROM Student s
 WHERE s.studentId = cs.studentId
),
 count(*) AS courses
 FROM CourseStudent cs
 JOIN Course c ON c.courseId = cs.courseId
 GROUP BY cs.studentId, c.professorId
 HAVING (count(*) > 1)
 
GO
--======================================Return the department has most hornored students
CREATE PROCEDURE [spGetHighestHonoredStudentsDepartment]
AS
 SELECT TOP(1) WITH TIES d.departmentId, d.departmentName, COUNT(*) AS NumOfHonorStudent
 FROM Department d
  JOIN Course c ON c.departmentId = d.departmentId
  JOIN CourseStudent cs ON cs.courseId = c.courseId
  JOIN Student s ON s.studentId = cs.studentId
 WHERE isHonorStudent = 1
 GROUP BY d.departmentId, d.departmentName
 ORDER BY NumOfHonorStudent DESC
GO
--======================================Return all the professor to see how many credit hours they have
--======================================if they have more than 6 credit hours' course, return "too much course",
--====================================== if they have more than 4 and less or equal 6, return "enough",
--====================================== if they have less than 4 courses, return "add some courses"
CREATE PROCEDURE [spGetProfessorCreditHours]
AS
 SELECT p.professorId,
 [Name] = p.firstName + ' ' + p.lastName,
 [totalHours] = SUM(c.creditHour),
 [Comments] = (
  CASE
  WHEN SUM(c.creditHour) >=6 THEN 'Too much courses'
  WHEN SUM(c.creditHour) >=4 AND SUM(c.creditHour)<6 THEN 'Enough'
  ELSE 'Add more Courses'
  END
  )
 FROM Professor p
  JOIN Course c ON c.professorId = p.professorId
 GROUP BY p.professorId, p.firstName + ' ' + p.lastName
GO

--=============================================Purposedly Built for Web 
--===========================================Add Student records
CREATE PROCEDURE [spAddStudent]
		@FirstName varchar(200), 
		@LastName varchar(200), 
		@credit int,
		@class varchar(50),
		@honor bit,
		@Email varchar(200), 
		@GPA float
AS
SET NOCOUNT ON
INSERT INTO [dbo].[Student]
           ([firstName]
           ,[lastName]
           ,[creditEarned]
           ,[class]
           ,[isHonorStudent]
           ,[email]
		   ,[GPA])
     VALUES
           (
			@FirstName, 
			@LastName, 
			@credit,
			@class,
			@honor,
			@Email, 
			@GPA)
GO

--===========================================Get Student List
CREATE PROCEDURE [spGetStudent]
AS
	SET NOCOUNT ON
	SELECT * FROM Student
GO


--===========================================Update Student records
CREATE PROCEDURE [spUpdateStudent]
		@studentId int,
		@FirstName varchar(200), 
		@LastName varchar(200), 
		@credit int,
		@class varchar(50),
		@honor bit,
		@Email varchar(200), 
		@GPA float
AS
	SET NOCOUNT ON
	UPDATE Student 
	SET [firstName] = @FirstName
           ,[lastName] = @LastName
           ,[creditEarned] = @credit
           ,[class] = @class
           ,[isHonorStudent] = @honor
           ,[email] = @Email
		   ,[GPA] = @GPA
	WHERE studentId = @studentId
GO

--===========================================Update Student records
CREATE PROCEDURE [spDeleteStudent]
		@studentId int
AS
	SET NOCOUNT ON
	DELETE FROM Student 
	WHERE studentId = @studentId
GO

--==========================================Example of Dealing with XML (You can Uncomment to try the code) 
--.................................................................................... Department XML Data


--DECLARE @XmlDepartment 	AS  XML

--SET @XmlDepartment= 	
--		'<Department>					
--			<Add deptChairId="4">				
--				<item name = "engineering" location = "PSY" phone="5135678921"/>
--			</Add>
--			<Add deptChairId="6">
--				<item name = "engineering" location = "FAM" phone="5134657890"/>
--			</Add>
--			<Update departmentId = "6" >
--				<item nname = "statistics" nlocation="" ndeptChairId="2" />
--			</Update>


--			<Delete deptId = "7"/>

--		</Department>'

----.................................................................................... INSERT
--INSERT INTO Department([departmentName],[location], [departmentChairId],[phone])
--SELECT n,  l, i, p 
--FROM (
--		SELECT	[i] = dept.value('@deptChairId','int'),
--			[n] = row.value('@name', 'varchar(200)'),
--			[l] = row.value('@location', 'varchar(200)') ,
--			[p] = row.value('@phone', 'varchar(50)')
--		FROM @XmlDepartment.nodes('/Department/Add') foo(dept) 
--			CROSS APPLY dept.nodes('item') bar(row)
--     ) tbl
--WHERE NOT EXISTS (SELECT NULL FROM Department WHERE [departmentChairId] = tbl.i)


----.................................................................................... UPDATES
----........................................................... V1

--UPDATE Department
--SET departmentName = nname, [location] = nlocation, [departmentChairId]=nChairId
--FROM	(	
--SELECT	[nname]     = row.value('@nname', 'varchar(200)'),
--			[nlocation] = row.value('@nlocation', 'varchar(200)'),
--			[nChairId] = row.value('@ndeptChairId', 'int'),
--			[id]     = dept.value('@departmentId', 'int') 
--		FROM	@XmlDepartment.nodes('/Department/Update') foo(dept)
--			cross apply dept.nodes('item') bar(row)
--	) as tbl
--WHERE departmentId = tbl.id

----.................................................................................... DELETE

--DELETE FROM Department
--WHERE departmentId IN (	SELECT 	dept.value('@deptId', 'int')
--		FROM	@XmlDepartment.nodes('/Department/Delete') foo(dept)
--)


