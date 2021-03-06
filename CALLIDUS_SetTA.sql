USE [SSATools]
GO
/****** Object:  StoredProcedure [dbo].[CALLIDUS_SetTA]    Script Date: 04/30/2015 14:13:44 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROC [dbo].[CALLIDUS_SetTA]
@AsofBookingDate DateTime
AS

/*
dbo.CALLIDUS_SetTA '12/09/2014'

select * from dbo.CALLIDUS_TA

*/

TRUNCATE TABLE dbo.CALLIDUS_TA
INSERT INTO dbo.CALLIDUS_TA
(
SuperRegionID,
TerritoryLevelID,
TerritoryID,
ORDERID,
LINENUMBER,
SUBLINENUMBER,
EVENTTYPEID,
POSITIONNAME
)

SELECT
DISTINCT 
SuperRegionID,
TerritoryLevelID,
TerritoryID,
l.TerritoryLevelCode +'_'+ CONVERT(VARCHAR(20),TerritoryID) ORDERID,
CONVERT(VARCHAR(1),DATEPART(Q,@AsofBookingDate)) LINENUMBER,
'1' SUBLINENUMBER,
'ACTUALS' EVENTTYPEID,
l.TerritoryLevelCode +'_'+ TerritoryName POSITIONNAME

FROM dbo.CALLIDUS_Territories l

/*
SELECT
DISTINCT 
SuperRegionID,
TerritoryLevelID,
 CASE l.TerritoryLevelCode
		--WHEN 'MAA' THEN MAAID
		WHEN 'MMA' THEN MMAID
		WHEN 'AMT' THEN AMTID
		WHEN 'Region' THEN RegionID
		WHEN 'SMT' THEN SMTID
		WHEN 'SuperRegion' THEN SuperRegionID END TerritoryID,
l.TerritoryLevelCode +'_'+ 
	CASE l.TerritoryLevelCode
		--WHEN 'MAA' THEN CONVERT(VARCHAR(20),MAAID)
		WHEN 'MMA' THEN CONVERT(VARCHAR(20),MMAID)
		WHEN 'AMT' THEN CONVERT(VARCHAR(20),AMTID)
		WHEN 'Region' THEN CONVERT(VARCHAR(20),RegionID)
		WHEN 'SMT' THEN CONVERT(VARCHAR(20),SMTID)
		WHEN 'SuperRegion' THEN CONVERT(VARCHAR(20),SuperRegionID) END + '_' + CONVERT(VARCHAR(10),@AsofBookingDate,101) ORDERID,
'1' LINENUMBER,
'1' SUBLINENUMBER,
'ACTUALS' EVENTTYPEID,
l.TerritoryLevelCode +'_'+ 
	CASE l.TerritoryLevelCode
		--WHEN 'MAA' THEN MAAName
		WHEN 'MMA' THEN MMAName
		WHEN 'AMT' THEN AMTName
		WHEN 'Region' THEN RegionName
		WHEN 'SMT' THEN SMTName
		WHEN 'SuperRegion' THEN SuperRegionName END POSITIONNAME

FROM 
(SELECT sip.* FROM SIP_Hierrachy sip 
	JOIN #Regions r ON sip.RegionID = r.RegionID) sip
CROSS JOIN SIP_TerritoryLevel l 
WHERE l.TerritoryLevelTypeID <= 50 
AND CASE l.TerritoryLevelCode
		--WHEN 'MAA' THEN MAAID
		WHEN 'MMA' THEN MMAID
		WHEN 'AMT' THEN AMTID
		WHEN 'Region' THEN RegionID
		WHEN 'SMT' THEN SMTID
		WHEN 'SuperRegion' THEN SuperRegionID END >0
*/