USE [SSATools]
GO
/****** Object:  StoredProcedure [dbo].[CALLIDUS_SetPreqs]    Script Date: 04/30/2015 14:13:14 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROC [dbo].[CALLIDUS_SetPreqs]
@QuarterBegin DateTime ='1/1/2015',
@QuarterEnd SmallInt = 0,
@IncludeMAAs Int = 0
AS
/*
[dbo].[CALLIDUS_SetPreqs] '1/1/2015',1
*/

DECLARE @Date_UpDate DateTime,@MaxSnapshotQuarter DateTime

SELECT @Date_UpDate = MIN(update_date) FROM [CHC-SQLPSG12].SSAtools.dbo.VIPHierarchy_Snapshot
	WHERE SnapshotQuarterBeginDate = @QuarterBegin
	
--SELECT @MaxSnapshotQuarter = MAX(SnapshotQuarterBeginDate) FROM [CHC-SQLPSG12].SSAtools.dbo.VIPHierarchy_Snapshot
	
SELECT MarketID,MarketName,MMAID,MMA MMAName,AMTID,AMTName,h.RegionID,RegionName,MAAID,MAA MAAName,
				SMTID,SMTName,SuperRegionID,SuperRegionName, COUNT(*) HotelCnt
INTO #Hierarchy	
FROM [CHC-SQLPSG12].SSAtools.dbo.VIPHierarchy_Snapshot h
JOIN (SELECT DISTINCT RegionID, SMTID, SMTName FROM dbo.KPI_GMM_VIP_Hierarchy_Snapshot
		WHERE SnapshotQuarterBeginDate =@QuarterBegin) vip ON h.RegionID = vip.RegionID
WHERE update_date = @Date_UpDate AND SnapshotQuarterBeginDate =@QuarterBegin 
	 AND ISNULL(SuperRegionID,0) >0 AND ExpediaID <>10023570
GROUP BY 
MarketID,MarketName,MMAID,MMA,AMTID,AMTName,h.RegionID,RegionName,MAAID,MAA,
				SMTID,SMTName,SuperRegionID,SuperRegionName


--deduping	
SELECT 
DISTINCT AMTID,MMAID
INTO #NoDupes
FROM
(
SELECT
AMTID,MMAID, SUM(HotelCnt) HotelCnt,
RANK() OVER(PARTITION BY MMAID ORDER BY SUM(HotelCnt) DESC) Rnk
FROM #Hierarchy
GROUP BY AMTID,MMAID
) s
WHERE Rnk = 1

DELETE  s
FROM #Hierarchy s
LEFT JOIN #NoDupes d
ON s.MMAID = d.MMAID AND s.AMTID = d.AMTID
WHERE d.AMTID IS NULL

---Retrieve all Territories & Levels
TRUNCATE TABLE dbo.CALLIDUS_Territories
INSERT INTO dbo.CALLIDUS_Territories
SELECT
DISTINCT 
	CASE l.TerritoryLevelCode
		WHEN 'MAA' THEN MAAID
		WHEN 'MMA' THEN MMAID
		WHEN 'AMT' THEN AMTID
		WHEN 'Region' THEN RegionID
		WHEN 'SMT' THEN SMTID
		WHEN 'SuperRegion' THEN SuperRegionID END TerritoryID,
	CASE l.TerritoryLevelCode
		WHEN 'MAA' THEN MAAName
		WHEN 'MMA' THEN MMAName
		WHEN 'AMT' THEN AMTName
		WHEN 'Region' THEN RegionName
		WHEN 'SMT' THEN SMTName
		WHEN 'SuperRegion' THEN SuperRegionName END TerritoryName,
CASE WHEN l.TerritoryLevelID <50 THEN MarketID END MarketID,
SuperRegionID,
TerritoryLevelID,
TerritoryLevelCode,
sip.RegionID
--INTO #Territories -- Drop Table #Territories
FROM #Hierarchy sip 
CROSS JOIN SIP_TerritoryLevel l 
WHERE l.TerritoryLevelID <= (CASE @IncludeMAAs WHEN 1 THEN 60 ELSE 50 END)
AND CASE l.TerritoryLevelCode
		WHEN 'MAA' THEN MAAID
		WHEN 'MMA' THEN MMAID
		WHEN 'AMT' THEN AMTID
		WHEN 'Region' THEN RegionID
		WHEN 'SMT' THEN SMTID
		WHEN 'SuperRegion' THEN SuperRegionID END >0

SELECT
DISTINCT 
	CASE l.TerritoryLevelCode
		WHEN 'MAA' THEN MAAID
		WHEN 'MMA' THEN MMAID
		WHEN 'AMT' THEN AMTID
		WHEN 'Region' THEN RegionID
		WHEN 'SMT' THEN SMTID
		WHEN 'SuperRegion' THEN SuperRegionID END TerritoryID,
	CASE l.TerritoryLevelCode
		WHEN 'MAA' THEN MAAName
		WHEN 'MMA' THEN MMAName
		WHEN 'AMT' THEN AMTName
		WHEN 'Region' THEN RegionName
		WHEN 'SMT' THEN SMTName
		WHEN 'SuperRegion' THEN SuperRegionName END TerritoryName,
CASE WHEN l.TerritoryLevelID <=50 THEN MMAID END MMAID,
SuperRegionID,
TerritoryLevelID,
TerritoryLevelCode
INTO #MMAs -- Drop Table #MMAs select * from #MMAs order by territorylevelid,superregionid
FROM dbo.KPI_GMM_VIP_Hierarchy_Snapshot sip 
CROSS JOIN SIP_TerritoryLevel l 
WHERE l.TerritoryLevelID <= 50 AND SnapshotQuarterBeginDate =@QuarterBegin 
AND CASE l.TerritoryLevelCode
		WHEN 'MAA' THEN MAAID
		WHEN 'MMA' THEN MMAID
		WHEN 'AMT' THEN AMTID
		WHEN 'Region' THEN RegionID
		WHEN 'SMT' THEN SMTID
		WHEN 'SuperRegion' THEN SuperRegionID END >0
	
SELECT DISTINCT AMTID,RegionID,SMTID,SuperRegionID 
INTO #VIP
	FROM dbo.KPI_GMM_VIP_Hierarchy_Snapshot
 WHERE SuperRegionID>0 AND SnapshotQuarterBeginDate=@QuarterBegin 
		
SELECT DISTINCT MMAID,AMTID,RegionID,SMTID,SuperRegionID
INTO #VIPMMas
	FROM dbo.KPI_GMM_VIP_Hierarchy_Snapshot
 WHERE SuperRegionID>0 AND SnapshotQuarterBeginDate=@QuarterBegin 
			
--Get all metrics for each level of reporting    
TRUNCATE TABLE dbo.CALLIDUS_AggregatedData
INSERT INTO dbo.CALLIDUS_AggregatedData
SELECT
    lv.TerritoryLevelID,
    lv.TerritoryID,
    lv.SuperRegionID,
    --RMD
    ISNULL(SUM(k.QTDcyActualRMD),0) QTDcyActualRMD,
    ISNULL(SUM(k.QTDPlanRMD),0) QTDPlanRMD,
    ISNULL(SUM(k.FullQPlanRMD),0) FullQPlanRMD,
    --NRN
    ISNULL(SUM(k.QTDcyActualNRN),0) QTDcyActualNRN,
    ISNULL(SUM(k.QTDPlanNRN),0) QTDPlanNRN,
    ISNULL(SUM(k.FullQPlanNRN),0) FullQPlanNRN,
    --HFS
    ISNULL(SUM(k.aNUM_HFS),0) aNUM_HFS,
    ISNULL(SUM(k.aDENOM_HFS),0) aDENOM_HFS,
    ISNULL(SUM(k.tNUM_HFS),0) tNUM_HFS,
    ISNULL(SUM(k.tDENOM_HFS),0) tDENOM_HFS,
    --Acq
    0 aAcq,
    0 tAcq,
    --Rate
    ISNULL(CASE WHEN SUM(k.aRateD) = 0 OR SUM(k.aRateN) = 0 THEN 0 ELSE (SUM(k.aRateN)/SUM(k.aRateD))*100 END,0) aRateScore,
    ISNULL(CASE WHEN SUM(k.tRateD) = 0 OR SUM(k.tRateN) = 0 THEN 0 ELSE (SUM(k.tRateN)/SUM(k.tRateD))*100 END,0) tRateScore,
    ISNULL(CASE WHEN SUM(k.aRateD) = 0 OR SUM(k.aRateN) = 0 THEN 0 ELSE (SUM(k.aRateN)/SUM(k.aRateD))*100 END
    -
    CASE WHEN SUM(k.tRateD) = 0 OR SUM(k.tRateN) = 0  OR SUM(k.aRateN) = 0 THEN 0 ELSE (SUM(k.tRateN)/SUM(k.tRateD))*100 END,0) RateDelta,
    --Avail/Inv
    ISNULL(CASE WHEN SUM(k.tAvailD) = 0 OR SUM(k.tAvailN) = 0 THEN 0 ELSE (SUM(k.tAvailN)/SUM(k.tAvailD))*100 END,0) tAvailScore,
    ISNULL(CASE WHEN SUM(k.aAvailD) = 0 OR SUM(k.aAvailN) = 0 THEN 0 ELSE (SUM(k.aAvailN)/SUM(k.aAvailD))*100 END,0) aAvailScore,
    
    ISNULL(CASE WHEN SUM(k.aAvailD) = 0 OR SUM(k.aAvailN) = 0 THEN 0 ELSE (SUM(k.aAvailN)/SUM(k.aAvailD))*100 END
    -
    CASE WHEN SUM(k.tAvailD) = 0 OR SUM(k.tAvailN) = 0 OR SUM(k.aAvailN) = 0 THEN 0 ELSE (SUM(k.tAvailN)/SUM(k.tAvailD))*100 END,0) AvailDelta,
    --Rate
    ISNULL(SUM(tRateD),0) tRateD,
    ISNULL(SUM(tRateN),0) tRateN,
    ISNULL(SUM(aRateD),0) aRateD,
    ISNULL(SUM(aRateN),0) aRateN,
    --Avail/Inv
    ISNULL(SUM(k.tAvailD),0) tAvailD,
    ISNULL(SUM(k.tAvailN),0) tAvailN,
    ISNULL(SUM(k.aAvailD),0) aAvailD,
    ISNULL(SUM(k.aAvailN),0) aAvailN,
    k.AsOfBookingDate,
    0
--INTO #Data -- Drop table #Data
FROM [CHC-SQLPSG12].ProdReports.[dbo].[KPIPulseData_Callidus] k
JOIN dbo.CALLIDUS_Territories lv ON ISNULL(lv.MarketID,lv.TerritoryID) = CASE lv.TerritoryLevelID 
																	WHEN 50 THEN k.MMAID
																	WHEN 60 THEN k.MAAID 
																	ELSE k.MarketID END
																  															  
GROUP BY 
    lv.TerritoryLevelID,
    lv.TerritoryID,
    lv.SuperRegionID,
    AsOfBookingDate
    
--Aggregate Acqs
CREATE TABLE #Acq
(
TerritoryLevelID INT,
TerritoryID INT,
aAcq INT,
tAcq INT,
pAcq INT
)

IF(@QuarterEnd=1)
	INSERT INTO #Acq
	SELECT 
	mma.TerritoryLevelID,
	mma.TerritoryID,
	SUM(EOQ_RMD_Actual) aAcq,
	SUM(RMD_Target) tAcq,
	SUM(RMD_Target) pAcq
	FROM #MMAs mma 
	JOIN [CHC-SQLPSG12].SSA.dbo.AP_KPI2015_ACQ_TAR acq
	ON acq.MMA_ID = mma.MMAID
	WHERE acq.date_update =@QuarterBegin
	GROUP BY 
	mma.TerritoryLevelID,
	mma.TerritoryID
ELSE
	INSERT INTO #Acq
	SELECT
	mma.TerritoryLevelID,
	mma.TerritoryID,
	aAcq = SUM(ISNULL(acq.aAcq,0)),
	tAcq = SUM(ISNULL(acq.tAcq,0)),
	pAcq = SUM(ISNULL(acq.pAcq*acq.tAcq,0))
	FROM #MMAs mma 
	JOIN [CHC-SQLPSG12].ProdReports.dbo.KPIAcq acq ON acq.MMAID = mma.MMAID
	GROUP BY
	mma.TerritoryLevelID,
	mma.TerritoryID
UPDATE d
SET d.aAcq = ISNULL(acq.aAcq,0),
	d.tAcq = ISNULL(acq.tAcq,0),
	d.pAcq = ISNULL(acq.pAcq,0)
FROM dbo.CALLIDUS_AggregatedData d
JOIN  #Acq acq ON d.TerritoryID = acq.TerritoryID AND d.TerritoryLevelID  = acq.TerritoryLevelID
        
 --Weights

EXEC  dbo.CALLIDUS_SetWEIGHTS @QuarterBegin
		
SELECT 
--Region
30 TerritoryLevelID,
vip.RegionID TerritoryID,
CASE WHEN SUM(d.QTDPlanRMD)<>0 THEN SUM(ISNULL(d.QTDPlanRMD * w.RMD_WEIGHT,0))/SUM(d.QTDPlanRMD) END RMD_WEIGHT,
CASE WHEN SUM(d.QTDPlanRMD)<>0 THEN SUM(ISNULL(d.QTDPlanRMD * w.NRN_WEIGHT,0))/SUM(d.QTDPlanRMD) END NRN_WEIGHT,
CASE WHEN SUM(d.QTDPlanRMD)<>0 THEN SUM(ISNULL(d.QTDPlanRMD * w.HFS_WEIGHT,0))/SUM(d.QTDPlanRMD) END HFS_WEIGHT,
CASE WHEN SUM(d.QTDPlanRMD)<>0 THEN SUM(ISNULL(d.QTDPlanRMD * w.Acq_WEIGHT,0))/SUM(d.QTDPlanRMD) END ACQ_WEIGHT,
CASE WHEN SUM(d.QTDPlanRMD)<>0 THEN SUM(ISNULL(d.QTDPlanRMD * w.Rate_WEIGHT,0))/SUM(d.QTDPlanRMD) END RATE_WEIGHT,
CASE WHEN SUM(d.QTDPlanRMD)<>0 THEN SUM(ISNULL(d.QTDPlanRMD * w.Inv_WEIGHT,0))/SUM(d.QTDPlanRMD) END INV_WEIGHT
INTO #Weights
FROM dbo.CALLIDUS_WEIGHTS w 
JOIN #VIP vip ON vip.AMTID = w.TerritoryID
LEFT JOIN dbo.CALLIDUS_AggregatedData d ON w.TerritoryID = d.TerritoryID AND w.TerritoryLevelID = d.TerritoryLevelID 
WHERE w.TerritoryLevelID = 40
GROUP BY 
vip.RegionID

INSERT INTO #Weights  
--SMT
SELECT 
20 TerritoryLevelID,
vip.SMTID TerritoryID,
CASE WHEN SUM(d.QTDPlanRMD)<>0 THEN SUM(ISNULL(d.QTDPlanRMD * w.RMD_WEIGHT,0))/SUM(d.QTDPlanRMD) END RMD_WEIGHT,
CASE WHEN SUM(d.QTDPlanRMD)<>0 THEN SUM(ISNULL(d.QTDPlanRMD * w.NRN_WEIGHT,0))/SUM(d.QTDPlanRMD) END NRN_WEIGHT,
CASE WHEN SUM(d.QTDPlanRMD)<>0 THEN SUM(ISNULL(d.QTDPlanRMD * w.HFS_WEIGHT,0))/SUM(d.QTDPlanRMD) END HFS_WEIGHT,
CASE WHEN SUM(d.QTDPlanRMD)<>0 THEN SUM(ISNULL(d.QTDPlanRMD * w.Acq_WEIGHT,0))/SUM(d.QTDPlanRMD) END ACQ_WEIGHT,
CASE WHEN SUM(d.QTDPlanRMD)<>0 THEN SUM(ISNULL(d.QTDPlanRMD * w.Rate_WEIGHT,0))/SUM(d.QTDPlanRMD) END RATE_WEIGHT,
CASE WHEN SUM(d.QTDPlanRMD)<>0 THEN SUM(ISNULL(d.QTDPlanRMD * w.Inv_WEIGHT,0))/SUM(d.QTDPlanRMD) END INV_WEIGHT
FROM dbo.CALLIDUS_WEIGHTS w 
JOIN #VIP vip ON vip.AMTID = w.TerritoryID
LEFT JOIN dbo.CALLIDUS_AggregatedData d ON w.TerritoryID = d.TerritoryID AND w.TerritoryLevelID = d.TerritoryLevelID
WHERE w.TerritoryLevelID = 40
GROUP BY vip.SMTID

UNION ALL
--SuperRegion
SELECT 
10 TerritoryLevelID,
vip.SuperRegionID TerritoryID,
CASE WHEN SUM(d.QTDPlanRMD)<>0 THEN SUM(ISNULL(d.QTDPlanRMD * w.RMD_WEIGHT,0))/SUM(d.QTDPlanRMD) END RMD_WEIGHT,
CASE WHEN SUM(d.QTDPlanRMD)<>0 THEN SUM(ISNULL(d.QTDPlanRMD * w.NRN_WEIGHT,0))/SUM(d.QTDPlanRMD) END NRN_WEIGHT,
CASE WHEN SUM(d.QTDPlanRMD)<>0 THEN SUM(ISNULL(d.QTDPlanRMD * w.HFS_WEIGHT,0))/SUM(d.QTDPlanRMD) END HFS_WEIGHT,
CASE WHEN SUM(d.QTDPlanRMD)<>0 THEN SUM(ISNULL(d.QTDPlanRMD * w.Acq_WEIGHT,0))/SUM(d.QTDPlanRMD) END ACQ_WEIGHT,
CASE WHEN SUM(d.QTDPlanRMD)<>0 THEN SUM(ISNULL(d.QTDPlanRMD * w.Rate_WEIGHT,0))/SUM(d.QTDPlanRMD) END RATE_WEIGHT,
CASE WHEN SUM(d.QTDPlanRMD)<>0 THEN SUM(ISNULL(d.QTDPlanRMD * w.Inv_WEIGHT,0))/SUM(d.QTDPlanRMD) END INV_WEIGHT
FROM dbo.CALLIDUS_WEIGHTS w 
JOIN #VIP vip ON vip.AMTID = w.TerritoryID
LEFT JOIN dbo.CALLIDUS_AggregatedData d ON w.TerritoryID = d.TerritoryID AND w.TerritoryLevelID = d.TerritoryLevelID
WHERE w.TerritoryLevelID = 40
GROUP BY vip.SuperRegionID

--AMT & MMA & MAA
INSERT INTO #Weights 
SELECT 
w.TerritoryLevelID,
w.TerritoryID,
CASE WHEN SUM(d.QTDPlanRMD)<>0 THEN SUM(ISNULL(d.QTDPlanRMD * w.RMD_WEIGHT,0))/SUM(d.QTDPlanRMD) END RMD_WEIGHT,
CASE WHEN SUM(d.QTDPlanRMD)<>0 THEN SUM(ISNULL(d.QTDPlanRMD * w.NRN_WEIGHT,0))/SUM(d.QTDPlanRMD) END NRN_WEIGHT,
CASE WHEN SUM(d.QTDPlanRMD)<>0 THEN SUM(ISNULL(d.QTDPlanRMD * w.HFS_WEIGHT,0))/SUM(d.QTDPlanRMD) END HFS_WEIGHT,
CASE WHEN SUM(d.QTDPlanRMD)<>0 THEN SUM(ISNULL(d.QTDPlanRMD * w.Acq_WEIGHT,0))/SUM(d.QTDPlanRMD) END ACQ_WEIGHT,
CASE WHEN SUM(d.QTDPlanRMD)<>0 THEN SUM(ISNULL(d.QTDPlanRMD * w.Rate_WEIGHT,0))/SUM(d.QTDPlanRMD) END RATE_WEIGHT,
CASE WHEN SUM(d.QTDPlanRMD)<>0 THEN SUM(ISNULL(d.QTDPlanRMD * w.Inv_WEIGHT,0))/SUM(d.QTDPlanRMD) END INV_WEIGHT
FROM dbo.CALLIDUS_WEIGHTS w 
LEFT JOIN dbo.CALLIDUS_AggregatedData d ON w.TerritoryID = d.TerritoryID AND w.TerritoryLevelID = d.TerritoryLevelID
WHERE w.TerritoryLevelID IN(40,50,60)
GROUP BY 
w.TerritoryLevelID,
w.TerritoryID

--Normalize
TRUNCATE TABLE dbo.CALLIDUS_NormalizedWeights
INSERT INTO dbo.CALLIDUS_NormalizedWeights
SELECT
TerritoryLevelID,
TerritoryID,
CASE WHEN (RMD_WEIGHT+NRN_WEIGHT+HFS_WEIGHT+ACQ_WEIGHT+RATE_WEIGHT+INV_WEIGHT)>0 THEN 
			RMD_WEIGHT/(RMD_WEIGHT+NRN_WEIGHT+HFS_WEIGHT+ACQ_WEIGHT+RATE_WEIGHT+INV_WEIGHT) ELSE 0 END RMD_WEIGHT,
CASE WHEN (RMD_WEIGHT+NRN_WEIGHT+HFS_WEIGHT+ACQ_WEIGHT+RATE_WEIGHT+INV_WEIGHT)>0 THEN 
			NRN_WEIGHT/(RMD_WEIGHT+NRN_WEIGHT+HFS_WEIGHT+ACQ_WEIGHT+RATE_WEIGHT+INV_WEIGHT) ELSE 0 END NRN_WEIGHT,
CASE WHEN (RMD_WEIGHT+NRN_WEIGHT+HFS_WEIGHT+ACQ_WEIGHT+RATE_WEIGHT+INV_WEIGHT)>0 THEN 
			HFS_WEIGHT/(RMD_WEIGHT+NRN_WEIGHT+HFS_WEIGHT+ACQ_WEIGHT+RATE_WEIGHT+INV_WEIGHT) ELSE 0 END HFS_WEIGHT,
CASE WHEN (RMD_WEIGHT+NRN_WEIGHT+HFS_WEIGHT+ACQ_WEIGHT+RATE_WEIGHT+INV_WEIGHT)>0 THEN 
			ACQ_WEIGHT/(RMD_WEIGHT+NRN_WEIGHT+HFS_WEIGHT+ACQ_WEIGHT+RATE_WEIGHT+INV_WEIGHT) ELSE 0 END ACQ_WEIGHT,
CASE WHEN (RMD_WEIGHT+NRN_WEIGHT+HFS_WEIGHT+ACQ_WEIGHT+RATE_WEIGHT+INV_WEIGHT)>0 THEN 
			RATE_WEIGHT/(RMD_WEIGHT+NRN_WEIGHT+HFS_WEIGHT+ACQ_WEIGHT+RATE_WEIGHT+INV_WEIGHT) ELSE 0 END RATE_WEIGHT,
CASE WHEN (RMD_WEIGHT+NRN_WEIGHT+HFS_WEIGHT+ACQ_WEIGHT+RATE_WEIGHT+INV_WEIGHT)>0 THEN 
			INV_WEIGHT/(RMD_WEIGHT+NRN_WEIGHT+HFS_WEIGHT+ACQ_WEIGHT+RATE_WEIGHT+INV_WEIGHT) ELSE 0 END INV_WEIGHT
FROM #Weights


