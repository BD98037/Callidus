USE [SSATools]
GO
/****** Object:  StoredProcedure [dbo].[CALLIDUS_SetFV]    Script Date: 04/30/2015 14:12:14 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROC [dbo].[CALLIDUS_SetFV]
@QuarterBegin DateTime,
@IncludeMAAs Int = 0
AS

DECLARE @TerritoryLevels VarChar(20)
IF(@IncludeMAAs=1)
SET @TerritoryLevels ='40,50,60'
ELSE SET @TerritoryLevels ='40,50'
/*
This sproc should be always excuted after the dbo.CALLIDUS_SetPosition sproc

dbo.CALLIDUS_SetFV '10/1/2014'

select * from dbo.CALLIDUS_FV

*/

TRUNCATE TABLE dbo.CALLIDUS_FV
INSERT INTO dbo.CALLIDUS_FV
(
SuperRegionID,
TerritoryLevelID,
TerritoryID,
NAME,
VALUE,
UNITTYPEFORVALUE,
PERIODTYPENAME,
EFFECTIVESTARTDATE/*,
EFFECTIVEENDDATE*/
)

SELECT
DISTINCT 
p.SuperRegionID,
p.TerritoryLevelID,
p.TerritoryID,
'FV_'+POSITIONNAME+'_'+ M.METRICS+'_'+METRICSTYPE NAME,
ISNULL(CASE m.[METRICSTYPE] 
				WHEN 'TAR' THEN CASE m.[METRICS]
					 WHEN 'TAV' THEN LTRIM(RTRIM(STR(d.FullQPlanRMD,25,5)))
					 WHEN 'NRN' THEN LTRIM(RTRIM(STR(d.FullQPlanNRN,25,5)))
					 WHEN 'HFS' THEN LTRIM(RTRIM(STR(CASE WHEN d.tDENOM_HFS = 0 THEN 0 ELSE d.tNUM_HFS/d.tDENOM_HFS END,25,5)))
					 WHEN 'ACQ' THEN LTRIM(RTRIM(STR(d.tAcq,25,5)))
					 WHEN 'Rate' THEN LTRIM(RTRIM(STR(d.tRateScore,25,5)))
					 WHEN 'INV' THEN LTRIM(RTRIM(STR(d.tAvailScore,25,5))) END
				WHEN 'WEIGHT' THEN CASE m.[METRICS]
					 WHEN 'TAV' THEN LTRIM(RTRIM(STR(w.RMD_WEIGHT,25,5)))
					 WHEN 'NRN' THEN LTRIM(RTRIM(STR(w.NRN_WEIGHT,25,5)))
					 WHEN 'HFS' THEN LTRIM(RTRIM(STR(w.HFS_WEIGHT,25,5)))
					 WHEN 'ACQ' THEN LTRIM(RTRIM(STR(w.ACQ_WEIGHT,25,5)))
					 WHEN 'Rate' THEN LTRIM(RTRIM(STR(w.Rate_WEIGHT,25,5)))
					 WHEN 'INV' THEN LTRIM(RTRIM(STR(w.Inv_WEIGHT,25,5))) END
				END,'00.0') VALUE,
CASE WHEN m.[METRICSTYPE] ='WEIGHT' THEN 'PERCENT'
		WHEN m.[METRICS] IN ('TAV','ACQ') THEN 'USD' WHEN m.[METRICS] = 'HFS'  THEN 'PERCENT' ELSE 'QUANTITY' END UNITTYPEFORVALUE,
'quarter' PERIODTYPENAME,
CONVERT(VARCHAR(10),@QuarterBegin,101) EFFECTIVESTARTDATE/*,
CONVERT(VARCHAR(10),DATEADD(d,-1,DATEADD(QUARTER,1,@QuarterBegin)),101) EFFECTIVEENDDATE*/

FROM dbo.CALLIDUS_POSITION P 
JOIN (SELECT [STR] TerritoryLevelID FROM dbo.charlist_to_table(@TerritoryLevels,DEFAULT)) l ON p.TerritoryLevelID = l.TerritoryLevelID
LEFT JOIN dbo.CALLIDUS_AggregatedData d ON p.SuperRegionID = d.SuperRegionID AND p.TerritoryLevelID = d.TerritoryLevelID AND p.TerritoryID = d.TerritoryID
LEFT JOIN dbo.CALLIDUS_NormalizedWeights w ON p.TerritoryLevelID = w.TerritoryLevelID AND P.TerritoryID = w.TerritoryID
CROSS JOIN dbo.CALLIDUS_METRICS M

