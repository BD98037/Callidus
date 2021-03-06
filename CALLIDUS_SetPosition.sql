USE [SSATools]
GO
/****** Object:  StoredProcedure [dbo].[CALLIDUS_SetPosition]    Script Date: 04/30/2015 14:12:47 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROC [dbo].[CALLIDUS_SetPosition]
@QuarterBegin DateTime,
@IncludeMAAs Int = 0
AS

/*
dbo.CALLIDUS_SetPosition '1/1/2015'

select * from dbo.CALLIDUS_POSITION ORDER BY SortOrder

select * from SIP_TerritoryLevel

select distinct roledescription from dbo.KPI_GMM_BottomUpAssignments_Snapshot

*/
/*
SELECT DISTINCT RegionName, RegionID, SuperRegionName, SuperRegionID
INTO #Regions
FROM Pliny.dbo.DimHotelExpand WHERE SuperRegionID>0
*/

TRUNCATE TABLE dbo.CALLIDUS_POSITION
INSERT INTO dbo.CALLIDUS_POSITION
(
SuperRegionID,
TerritoryLevelID,
TerritoryID,
POSITIONNAME,
EFFECTIVESTARTDATE,
EFFECTIVEENDDATE,
PAYEEID,
PAYEETYPE,
MANAGERNAME,
TITLENAME,
CREDITSTARTDATE,
CREDITENDDATE,
PROCESSINGSTARTDATE,
PROCESSINGENDDATE
)

SELECT
DISTINCT 
SuperRegionID,
l.TerritoryLevelID,
CASE l.TerritoryLevelCode
		WHEN 'MAA' THEN MAAID
		WHEN 'MMA' THEN MMAID
		WHEN 'AMT' THEN AMTID
		WHEN 'Region' THEN RegionID
		WHEN 'SMT' THEN SMTID
		WHEN 'SuperRegion' THEN SuperRegionID END TerritoryID,
l.TerritoryLevelCode +'_'+ 
	CASE l.TerritoryLevelCode
		WHEN 'MAA' THEN MAAName
		WHEN 'MMA' THEN MMAName
		WHEN 'AMT' THEN AMTName
		WHEN 'Region' THEN RegionName
		WHEN 'SMT' THEN SMTName
		WHEN 'SuperRegion' THEN SuperRegionName END POSITIONNAME,
CONVERT(VARCHAR(10),@QuarterBegin,101) EFFECTIVESTARTDATE,
CONVERT(VARCHAR(10),DATEADD(QUARTER,1,@QuarterBegin),101) EFFECTIVESTARTDATE,
'TBD' PAYEEID, 
'Participant' PAYEETYPE,
CASE l.TerritoryLevelCode
		WHEN 'MAA' THEN 'AMT_'+ AMTName
		WHEN 'MMA' THEN 'AMT_'+ AMTName
		WHEN 'AMT' THEN 'Region_'+ RegionName
		WHEN 'Region' THEN 'SMT_'+ SMTName
		WHEN 'SMT' THEN 'SuperRegion_'+ SuperRegionName
		WHEN 'SuperRegion' THEN '' END MANAGERNAME,
SuperRegionName TITLENAME, 
CONVERT(VARCHAR(10),@QuarterBegin,101) CREDITSTARTDATE,
CONVERT(VARCHAR(10),DATEADD(QUARTER,1,@QuarterBegin),101) CREDITENDDATE,
CONVERT(VARCHAR(10),@QuarterBegin,101) PROCESSINGSTARTDATE,
CONVERT(VARCHAR(10),DATEADD(QUARTER,1,@QuarterBegin),101) PROCESSINGENDDATE
  

FROM 
(SELECT DISTINCT sip.SuperRegionID,sip.SuperRegionName,sip.RegionID,sip.RegionName,
				sip.SMTID,sip.SMTName,sip.AMTID,sip.AMTName,sip.MMAName,sip.MMAID ,sip.MAAID,sip.MAAName
					FROM  dbo.KPI_GMM_VIP_Hierarchy_Snapshot sip
					WHERE SnapshotQuarterBeginDate =@QuarterBegin ) sip 
CROSS JOIN SIP_TerritoryLevel l 
WHERE l.TerritoryLevelTypeID <= 60 
AND CASE l.TerritoryLevelCode
		WHEN 'MAA' THEN MAAID
		WHEN 'MMA' THEN MMAID
		WHEN 'AMT' THEN AMTID
		WHEN 'Region' THEN RegionID
		WHEN 'SMT' THEN SMTID
		WHEN 'SuperRegion' THEN SuperRegionID END >0
		
UPDATE p
SET p.PAYEEID = CASE WHEN d.UserAlias LIKE '%@%' THEN ISNULL(SUBSTRING(d.UserAlias,1,CHARINDEX('@',d.UserAlias,1)-1),'TBD')
					  WHEN d.UserAlias ='Unassigned' THEN 'TBD'
						ELSE ISNULL(d.UserAlias,'TBD') END,
	p.TITLENAME =  CASE WHEN ISNULL(RoleDescription,'Unassigned') = 'Unassigned' THEN 'TBD' ELSE RoleDescription END +'_'+ p.TITLENAME,
	p.SortOrder = CASE WHEN RoleDescription = 'MMVP' THEN 1
					WHEN RoleDescription = 'SDMM' THEN 2
					WHEN RoleDescription = 'DMM' THEN 3
					WHEN RoleDescription = 'AM' THEN 4
					WHEN RoleDescription = 'sMM' THEN 5
					WHEN RoleDescription = 'MM' THEN 6
					WHEN RoleDescription = 'aMM' THEN 7 END
FROM dbo.CALLIDUS_POSITION p
JOIN dbo.KPI_GMM_BottomUpAssignments_Snapshot a -- [dbo].[SIP_AssignmentRules] a 
ON a.TerritoryID = p.TerritoryID AND a.TerritoryLevelID = p.TerritoryLevelID
LEFT JOIN (SELECT MIN(TerritoryLevelID) TerritoryLevelID,UserAlias 
				FROM dbo.KPI_GMM_BottomUpAssignments_Snapshot --[dbo].[SIP_AssignmentRules]
				WHERE SnapshotQuarterBeginDate = @QuarterBegin
			GROUP BY UserAlias) d
ON a.UserAlias = d.UserAlias AND a.TerritoryLevelID = d.TerritoryLevelID
--LEFT JOIN dbo.KPIRoleLookUp r ON r.RoleID = a.RoleID
WHERE SnapshotQuarterBeginDate = @QuarterBegin

IF(@IncludeMAAs=0)
DELETE FROM dbo.CALLIDUS_POSITION
WHERE TerritoryLevelID =60

/*
SELECT
DISTINCT 'MAA_'+ MAAName POSITIONNAME,
CONVERT(VARCHAR(10),@QuarterBegin,101) EFFECTIVESTARTDATE,
NULL PAYEEID, -- this will be populated once Expedient provides data
'Participant' PAYEETYPE,
'AMT_'+ AMTName MANAGERNAME,
NULL TITLENAME, -- this will be populated once Expedient provides data
CONVERT(VARCHAR(10),@QuarterBegin,101) CREDITSTARTDATE,
CONVERT(VARCHAR(10),DATEADD(d,-1,DATEADD(QUARTER,1,@QuarterBegin)),101) CREDITENDDATE,
CONVERT(VARCHAR(10),@QuarterBegin,101) PROCESSINGSTARTDATE,
'01/01/2020' PROCESSINGENDDATE

FROM SIP_Hierrachy sip WHERE MAAID>0

UNION ALL

SELECT
DISTINCT 'MMA_'+ MMAName POSITIONNAME,
CONVERT(VARCHAR(10),@QuarterBegin,101) EFFECTIVESTARTDATE,
NULL PAYEEID, -- this will be populated once Expedient provides data
'Participant' PAYEETYPE,
'AMT_'+ AMTName MANAGERNAME,
NULL TITLENAME, -- this will be populated once Expedient provides data
CONVERT(VARCHAR(10),@QuarterBegin,101) CREDITSTARTDATE,
CONVERT(VARCHAR(10),DATEADD(d,-1,DATEADD(QUARTER,1,@QuarterBegin)),101) CREDITENDDATE,
CONVERT(VARCHAR(10),@QuarterBegin,101) PROCESSINGSTARTDATE,
'01/01/2020' PROCESSINGENDDATE

FROM SIP_Hierrachy sip WHERE MMAID>0

UNION ALL

SELECT
DISTINCT 'AMT_'+ AMTName POSITIONNAME,
CONVERT(VARCHAR(10),@QuarterBegin,101) EFFECTIVESTARTDATE,
NULL PAYEEID, -- this will be populated once Expedient provides data
'Participant' PAYEETYPE,
'Region_'+ RegionName MANAGERNAME,
NULL TITLENAME, -- this will be populated once Expedient provides data
CONVERT(VARCHAR(10),@QuarterBegin,101) CREDITSTARTDATE,
CONVERT(VARCHAR(10),DATEADD(d,-1,DATEADD(QUARTER,1,@QuarterBegin)),101) CREDITENDDATE,
CONVERT(VARCHAR(10),@QuarterBegin,101) PROCESSINGSTARTDATE,
'01/01/2020' PROCESSINGENDDATE

FROM SIP_Hierrachy sip 
JOIN
(SELECT DISTINCT RegionName, RegionID FROM Pliny.dbo.DimHotelExpand) r ON sip.RegionID = r.RegionID WHERE AMTID>0

UNION ALL

SELECT
DISTINCT 'Region_'+ RegionName POSITIONNAME,
CONVERT(VARCHAR(10),@QuarterBegin,101) EFFECTIVESTARTDATE,
NULL PAYEEID, -- this will be populated once Expedient provides data
'Participant' PAYEETYPE,
'SMT_'+ SMTName MANAGERNAME,
NULL TITLENAME, -- this will be populated once Expedient provides data
CONVERT(VARCHAR(10),@QuarterBegin,101) CREDITSTARTDATE,
CONVERT(VARCHAR(10),DATEADD(d,-1,DATEADD(QUARTER,1,@QuarterBegin)),101) CREDITENDDATE,
CONVERT(VARCHAR(10),@QuarterBegin,101) PROCESSINGSTARTDATE,
'01/01/2020' PROCESSINGENDDATE

FROM SIP_Hierrachy sip 
JOIN
(SELECT DISTINCT RegionName, RegionID FROM Pliny.dbo.DimHotelExpand) r ON sip.RegionID = r.RegionID WHERE r.RegionID>0

UNION ALL

SELECT
DISTINCT 'SMT_'+ SMTName POSITIONNAME,
CONVERT(VARCHAR(10),@QuarterBegin,101) EFFECTIVESTARTDATE,
NULL PAYEEID, -- this will be populated once Expedient provides data
'Participant' PAYEETYPE,
'SuperRegion_'+ SuperRegionName MANAGERNAME,
NULL TITLENAME, -- this will be populated once Expedient provides data
CONVERT(VARCHAR(10),@QuarterBegin,101) CREDITSTARTDATE,
CONVERT(VARCHAR(10),DATEADD(d,-1,DATEADD(QUARTER,1,@QuarterBegin)),101) CREDITENDDATE,
CONVERT(VARCHAR(10),@QuarterBegin,101) PROCESSINGSTARTDATE,
'01/01/2020' PROCESSINGENDDATE

FROM SIP_Hierrachy sip 
JOIN
(SELECT DISTINCT SuperRegionName, SuperRegionID FROM Pliny.dbo.DimHotelExpand) r ON sip.SuperRegionID = r.SuperRegionID WHERE SMTID>0

UNION ALL

SELECT
DISTINCT 'SuperRegion_'+ SuperRegionName POSITIONNAME,
CONVERT(VARCHAR(10),@QuarterBegin,101) EFFECTIVESTARTDATE,
NULL PAYEEID, -- this will be populated once Expedient provides data
'Participant' PAYEETYPE,
'#N/A'  MANAGERNAME,
NULL TITLENAME, -- this will be populated once Expedient provides data
CONVERT(VARCHAR(10),@QuarterBegin,101) CREDITSTARTDATE,
CONVERT(VARCHAR(10),DATEADD(d,-1,DATEADD(QUARTER,1,@QuarterBegin)),101) CREDITENDDATE,
CONVERT(VARCHAR(10),@QuarterBegin,101) PROCESSINGSTARTDATE,
'01/01/2020' PROCESSINGENDDATE

FROM 
(SELECT DISTINCT SuperRegionName, SuperRegionID FROM Pliny.dbo.DimHotelExpand WHERE SuperRegionID > 0) r  
*/