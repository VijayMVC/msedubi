﻿/*
Deployment script for HigherED_DW

This code was generated by a tool.
Changes to this file may cause incorrect behavior and will be lost if
the code is regenerated.
*/

GO
SET ANSI_NULLS, ANSI_PADDING, ANSI_WARNINGS, ARITHABORT, CONCAT_NULL_YIELDS_NULL, QUOTED_IDENTIFIER ON;

SET NUMERIC_ROUNDABORT OFF;


GO
:setvar DatabaseName "HigherED_DW"
:setvar DefaultFilePrefix "HigherED_DW"
:setvar DefaultDataPath "c:\SQLServer\MSSQL13.MSSQLSERVER\MSSQL\DATA\"
:setvar DefaultLogPath "c:\SQLServer\MSSQL13.MSSQLSERVER\MSSQL\Log\"

GO
:on error exit
GO
/*
Detect SQLCMD mode and disable script execution if SQLCMD mode is not supported.
To re-enable the script after enabling SQLCMD mode, execute the following:
SET NOEXEC OFF; 
*/
:setvar __IsSqlCmdEnabled "True"
GO
IF N'$(__IsSqlCmdEnabled)' NOT LIKE N'True'
    BEGIN
        PRINT N'SQLCMD mode must be enabled to successfully execute this script.';
        SET NOEXEC ON;
    END


GO
USE [$(DatabaseName)];


GO
/* Create ML Input Views */
DROP VIEW IF EXISTS MLInput.Clusters;
GO

CREATE VIEW MLInput.Clusters 
AS
SELECT DISTINCT
fes.StudentSK AS StudentID
,dt.TermAK AS TermID
,fes.[ResidencyStatusSK] AS ResidencyID
,fes.[AcademicLevelSK] AS AcademicLevelID
,ds.Gender
,ds.Age
,ds.StateAbbrev
,dt.Term
,drs.[ResidencyStatus]
,dal.[AcademicLevel]
,fes.[CreditHoursAttempted]
,fes.[CreditHoursEarned]
,CAST(fes.[TermGPA] AS float) AS TermGPA
,CAST(fes.[TransferCredit] AS float) AS TransferCredit
,fes.[CumCreditHoursAtempted]
,fes.[CumCreditHoursEarned]
,CAST(fes.[CumGPA] AS float) AS CumGPA
FROM
[dbo].[FactEnrollmentSummary] fes
INNER JOIN [dbo].[DimStudent] ds ON fes.StudentSK = ds.StudentSK
INNER JOIN [dbo].[DimDate] dt ON fes.EnrollmentTermDateSK = dt.DateSK
INNER JOIN [dbo].[DimResidencyStatus] drs ON fes.[ResidencyStatusSK] = drs.[ResidencyStatusSK]
INNER JOIN [dbo].[DimAcademicLevel] dal ON fes.[AcademicLevelSK] = dal.[AcademicLevelSK]
INNER JOIN (SELECT fesi.StudentSK,fesi.[ResidencyStatusSK],fesi.[AcademicLevelSK], MAX((CAST(fesi.[CreditHoursEarned] AS decimal(5,3)) + CAST(fesi.[CumCreditHoursEarned] AS decimal(5,3)) + fesi.[CumGPA])) AS [LastRecID] FROM [dbo].[FactEnrollmentSummary] fesi GROUP BY fesi.StudentSK,fesi.[ResidencyStatusSK],fesi.[AcademicLevelSK]) lastrec
	ON lastrec.StudentSK = fes.StudentSK AND lastrec.[ResidencyStatusSK] = fes.[ResidencyStatusSK] AND lastrec.[AcademicLevelSK] = fes.[AcademicLevelSK] AND lastrec.[LastRecID] = (CAST(fes.[CreditHoursEarned] AS decimal(5,3)) + CAST(fes.[CumCreditHoursEarned] AS decimal(5,3)) + fes.[CumGPA])
WHERE
fes.StudentSK > -1;
GO

DROP VIEW IF EXISTS MLInput.DropClass;
GO

CREATE VIEW MLInput.DropClass 
AS
SELECT DISTINCT
ds.StudentSK AS StudentID
,dt.TermAK AS TermID
,dc.SubjectAK AS SubjectID
,dc.[CatalogAK] AS CatalogID
,fed.[ClassSK] AS ClassID
,dc.[ClassSectionAK] AS SectionID
,fed.EnrollDateSK AS EnrollDate
,fed.DropDateSK AS DropDate
,ds.Gender
,ds.Age
,ds.City
,ds.StateAbbrev
,ds.PostalCode
,ds.AdmitTerm
,dt.Term
,dt.SchoolYear
,dc.SubjectAK AS [Subject]
,dc.[CatalogAK] AS [Catalog]
,dc.[ClassSectionAK] AS [Section]
,dc.Title AS Class
,dc.CreditHours
,fed.Enrolled
,fed.Dropped
,fed.MidTermGrade
,fed.EndSemesterGrade
FROM
[dbo].[FactEnrollmentDetails] fed
INNER JOIN [dbo].[DimStudent] ds ON fed.StudentSK = ds.StudentSK
INNER JOIN [dbo].[DimDate] dt ON fed.EnrollmentTermDateSK = dt.DateSK
INNER JOIN [dbo].[DimClass] dc ON fed.ClassSK = dc.ClassSK
INNER JOIN (SELECT ds.StudentSK,dc.SubjectAK,dc.[CatalogAK],fed.[ClassSK],dc.[ClassSectionAK],MIN(fed.MidTermGrade) AS LastRecID FROM [dbo].[FactEnrollmentDetails] fed INNER JOIN [dbo].[DimStudent] ds ON fed.StudentSK = ds.StudentSK INNER JOIN [dbo].[DimClass] dc ON fed.ClassSK = dc.ClassSK GROUP BY ds.StudentSK,dc.SubjectAK,dc.[CatalogAK],fed.[ClassSK],dc.[ClassSectionAK]) lastrec
	ON lastrec.StudentSK = ds.StudentSK AND lastrec.SubjectAK = dc.SubjectAK AND lastrec.CatalogAK = dc.[CatalogAK] AND lastrec.ClassSK = fed.[ClassSK] AND lastrec.ClassSectionAK = dc.[ClassSectionAK] AND lastrec.LastRecID = fed.MidTermGrade
INNER JOIN (SELECT ds.StudentSK,dc.SubjectAK,dc.[CatalogAK],fed.[ClassSK],dc.[ClassSectionAK],MIN(fed.EndSemesterGrade) AS LastRecID FROM [dbo].[FactEnrollmentDetails] fed INNER JOIN [dbo].[DimStudent] ds ON fed.StudentSK = ds.StudentSK INNER JOIN [dbo].[DimClass] dc ON fed.ClassSK = dc.ClassSK GROUP BY ds.StudentSK,dc.SubjectAK,dc.[CatalogAK],fed.[ClassSK],dc.[ClassSectionAK]) lastrec1
	ON lastrec1.StudentSK = ds.StudentSK AND lastrec1.SubjectAK = dc.SubjectAK AND lastrec1.CatalogAK = dc.[CatalogAK] AND lastrec1.ClassSK = fed.[ClassSK] AND lastrec1.ClassSectionAK = dc.[ClassSectionAK] AND lastrec1.LastRecID = fed.EndSemesterGrade
WHERE 
ds.StudentSK  > 0;
GO

DROP VIEW IF EXISTS MLInput.FinalGrade;
GO

CREATE VIEW MLInput.FinalGrade 
AS
SELECT DISTINCT
ds.StudentSK AS StudentID
,dt.TermAK AS TermID
,dc.SubjectAK AS SubjectID
,dc.[CatalogAK] AS CatalogID
,fed.[ClassSK] AS ClassID
,dc.[ClassSectionAK] AS SectionID
,fed.EnrollDateSK AS EnrollDate
,fed.DropDateSK AS DropDate
,ds.Gender
,ds.Age
,ds.City
,ds.StateAbbrev
,ds.PostalCode
,ds.AdmitTerm
,dt.Term
,dt.SchoolYear
,dc.SubjectAK AS [Subject]
,dc.[CatalogAK] AS [Catalog]
,dc.[ClassSectionAK] AS [Section]
,dc.Title AS Class
,dc.CreditHours
,fed.Enrolled
,fed.Dropped
,fed.MidTermGrade
,fed.EndSemesterGrade
FROM
[dbo].[FactEnrollmentDetails] fed
INNER JOIN [dbo].[DimStudent] ds ON fed.StudentSK = ds.StudentSK
INNER JOIN [dbo].[DimDate] dt ON fed.EnrollmentTermDateSK = dt.DateSK
INNER JOIN [dbo].[DimClass] dc ON fed.ClassSK = dc.ClassSK
INNER JOIN (SELECT ds.StudentSK,dc.SubjectAK,dc.[CatalogAK],fed.[ClassSK],dc.[ClassSectionAK],MIN(fed.MidTermGrade) AS LastRecID FROM [dbo].[FactEnrollmentDetails] fed INNER JOIN [dbo].[DimStudent] ds ON fed.StudentSK = ds.StudentSK INNER JOIN [dbo].[DimClass] dc ON fed.ClassSK = dc.ClassSK GROUP BY ds.StudentSK,dc.SubjectAK,dc.[CatalogAK],fed.[ClassSK],dc.[ClassSectionAK]) lastrec
	ON lastrec.StudentSK = ds.StudentSK AND lastrec.SubjectAK = dc.SubjectAK AND lastrec.CatalogAK = dc.[CatalogAK] AND lastrec.ClassSK = fed.[ClassSK] AND lastrec.ClassSectionAK = dc.[ClassSectionAK] AND lastrec.LastRecID = fed.MidTermGrade
INNER JOIN (SELECT ds.StudentSK,dc.SubjectAK,dc.[CatalogAK],fed.[ClassSK],dc.[ClassSectionAK],MIN(fed.EndSemesterGrade) AS LastRecID FROM [dbo].[FactEnrollmentDetails] fed INNER JOIN [dbo].[DimStudent] ds ON fed.StudentSK = ds.StudentSK INNER JOIN [dbo].[DimClass] dc ON fed.ClassSK = dc.ClassSK GROUP BY ds.StudentSK,dc.SubjectAK,dc.[CatalogAK],fed.[ClassSK],dc.[ClassSectionAK]) lastrec1
	ON lastrec1.StudentSK = ds.StudentSK AND lastrec1.SubjectAK = dc.SubjectAK AND lastrec1.CatalogAK = dc.[CatalogAK] AND lastrec1.ClassSK = fed.[ClassSK] AND lastrec1.ClassSectionAK = dc.[ClassSectionAK] AND lastrec1.LastRecID = fed.EndSemesterGrade
WHERE 
ds.StudentSK  > 0
AND LEN(ISNULL(fed.EndSemesterGrade,'')) > 0
AND fed.EndSemesterGrade IN ('A','B','C','D','E','F');
GO

/* Load MLService metadata */
TRUNCATE TABLE MLMetadata.MLServices;
GO

INSERT INTO MLMetadata.MLServices
SELECT
'https://ussouthcentral.services.azureml.net/subscriptions/305180cdc5ab4c0fb752c85bdcf5dc88/services/5040eb01279448079bef44c711ec32a4/execute?api-version=2.0&format=swagger' AS apiURL
,'b6STTx1kxzPcLBvlL0QgjV0DB7aSf8NZckJw0+0hG1oaA7xYsEKvh73jI7kVlpcYp3R/TM1PngJUJc5geZZIPQ==' AS apiKey
,'{"Inputs":{},"GlobalParameters":{}}' AS inputJSON
,'[MLOutput].[StudentDropClass]' AS MLResultsTable
UNION ALL
SELECT
'https://ussouthcentral.services.azureml.net/subscriptions/305180cdc5ab4c0fb752c85bdcf5dc88/services/7151156a4f0a472e9bbea8626372dac7/execute?api-version=2.0&format=swagger' AS apiURL
,'kluLYQy1xO8X+ESPdnrTT2medOz7R4gFJVWcXAvIK2ZpVZ85HA8dw1WfQu9GAnwhbDcknAPIDxwxjE9gwo77qw==' AS apiKey
,'{"Inputs":{},"GlobalParameters":{}}' AS inputJSON
,'[MLOutput].[StudentClusters]' AS MLResultsTable
UNION ALL
SELECT
'https://ussouthcentral.services.azureml.net/subscriptions/305180cdc5ab4c0fb752c85bdcf5dc88/services/00e8b91043c441059b7880ef59fd1cea/execute?api-version=2.0&format=swagger' AS apiURL
,'Zz8xaGN42Hh8KMuDqi60MBjvvjrVKpacd5Uav/8XHG8/cmYkRaIozRPNR8vShhhlAUHJZoeebb0JzWFE6u9Tbw==' AS apiKey
,'{"Inputs":{},"GlobalParameters":{}}' AS inputJSON
,'[MLOutput].[StudentFinalGradeEstimate]' AS MLResultsTable
;
GO

GO
PRINT N'Update complete.';


GO
