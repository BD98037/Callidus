USE [SSATools]
GO
/****** Object:  StoredProcedure [dbo].[CALLIDUS_SetWEIGHTS]    Script Date: 04/30/2015 14:15:11 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROC [dbo].[CALLIDUS_SetWEIGHTS]
@QuarterBegin DateTime ='1/1/2015'
AS

TRUNCATE TABLE dbo.CALLIDUS_WEIGHTS
INSERT INTO dbo.CALLIDUS_WEIGHTS
SELECT DISTINCT
	st.TerritoryLevelID,
	st.TerritoryLevelCode,
	st.TerritoryID
	,COALESCE(t.tTeamMgmt,r.tTeamMgmt,sr.tTeamMgmt,0)  AS TeamManagement_Allocation
	,COALESCE(t.tAccntMgmt,r.tAccntMgmt,sr.tAccntMgmt,0)  AS AccntManagement_Allocation
	,COALESCE(t.tBML,r.tBML,sr.tBML,0) AS BML_Allocation
	,COALESCE(t.tAcq,r.tAcq,sr.tAcq,0)  AS Acquisition_Allocation
	,COALESCE(t.tHFS,r.tHFS,sr.tHFS,0)  AS Pkg_Allocation
	,COALESCE(t.tLocalProjects,r.tLocalProjects,sr.tLocalProjects,0)  AS LocalProjects_Allocation
	,COALESCE(t.tPTO,r.tPTO,sr.tPTO,0)  AS PTO_Allocation
	,COALESCE(t.wRMD,r.wRMD,sr.wRMD,0) AS RMD_Weight
	,COALESCE(t.wNRN,r.wNRN,sr.wNRN,0) AS NRN_Weight
	,COALESCE(t.wRate,r.wRate,sr.wRate,0) AS Rate_Weight
	,COALESCE(t.wInv,r.wInv,sr.wInv,0) AS Inv_Weight
	,ISNULL(CASE ISNULL(HFS_Target,0) WHEN 0 THEN 0 ELSE COALESCE(t.wHFS,r.wHFS,sr.wHFS,0) END,0) AS HFS_Weight
	,COALESCE(t.wAcq,r.wAcq,sr.wAcq,0) AS Acq_Weight
 FROM CALLIDUS_Territories st
	JOIN dbo.KPI_GMM_BottomUpAssignments_Snapshot a 
	ON a.TerritoryLevelID = st.TerritoryLevelID AND a.TerritoryID = st.TerritoryID
	LEFT JOIN KPI_GMMHFSTarget_Snapshot hfs 
	ON hfs.TerritoryID = st.TerritoryID AND hfs.TerritoryLevelID = st.TerritoryLevelID AND hfs.SnapshotQuarterBeginDate = @QuarterBegin
	LEFT JOIN [dbo].[KPI_GMMTimeAndWeightAllocationsByTerritoryExceptions_Snapshot] t
	ON a.TerritoryLevelID = t.TerritoryLevelID AND a.TerritoryID = t.TerritoryID AND a.SnapshotQuarterBeginDate = t.SnapshotQuarterBeginDate
	LEFT JOIN dbo.KPI_GMMTimeAndWeightAllocationsByRegionExceptions_Snapshot r 
	ON st.RegionID = r.RegionID	AND (r.RoleBucketID = CASE a.RoleBucketID WHEN 0 THEN CASE st.TerritoryLevelID WHEN 40 THEN 1 WHEN 50 THEN 2 WHEN 60 THEN 3 END ELSE a.RoleBucketID END) AND r.ScenarioID = CASE WHEN HFS_Target >0 THEN 1 ELSE 0 END AND r.SnapshotQuarterBeginDate = @QuarterBegin
	LEFT JOIN dbo.KPI_GMMTimeAndWeightAllocationsBySuperRegion_Snapshot sr
	ON st.SuperRegionID = sr.SuperregionID AND (sr.RoleBucketID = CASE a.RoleBucketID WHEN 0 THEN CASE st.TerritoryLevelID WHEN 40 THEN 1 WHEN 50 THEN 2 WHEN 60 THEN 3 END ELSE a.RoleBucketID END) AND sr.ScenarioID = CASE WHEN HFS_Target >0 THEN 1 ELSE 0 END AND sr.SnapshotQuarterBeginDate = @QuarterBegin
WHERE st.TerritoryLevelID IN (40,50,60) AND a.SnapshotQuarterBeginDate = @QuarterBegin

