USE [SSATools]
GO
/****** Object:  StoredProcedure [dbo].[CALLIDUS_RenameFiles]    Script Date: 04/30/2015 14:11:53 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROC [dbo].[CALLIDUS_RenameFiles]
AS
/*
cust_OGPO_DEV_20070805_134257_JULY07.txt -- Position
cust_PLFV_DEV_20070805_134257_JULY07.txt -- FV
cust_PLVA_DEV_20070805_134257_JULY07.txt -- VA
cust_TXSTA_DEV_20070805_134257_JULY07.txt -- TX
cust_TXTA_DEV_20070805_134257_JULY07.txt -- TA
*/


DECLARE
@FileLocation Varchar(500), 
@FileLocation2 Varchar(500), 
@FileName Varchar(500),
@NewFileName Varchar(500),
@CmdDir Varchar(500),
@Status Int = 1,
@Error Varchar(100),
@Now DateTime,
@QuarterBegin DateTime,
@DateStamp Varchar(50),
@CmdRename Varchar(500),
@CmdCopy Varchar(500),
@CmdDelete Varchar(500),
@FileID INT

SET @Now =GETDATE()

SELECT @QuarterBegin = Common.dbo.GetQtrBegin(AsOfBookingDate) FROM dbo.CALLIDUS_AggregatedData--[CHC-SQLPSG12].ProdReports.[dbo].[KPIPulseData]

SET @DateStamp  = CONVERT(VARCHAR(8),@Now,112)+'_'+REPLACE(CONVERT(VARCHAR(8),GETDATE(),114),':','')+'_'+DATENAME(MONTH,@QuarterBegin)+CONVERT(VARCHAR(2),RIGHT(YEAR(@QuarterBegin),2))

SET @FileLocation = '\\BEL-PFS-01\Hotel_Sales_Team\REPORTS\CURRENT\Other\BryanDoan\CallidusFeed\'
SET @FileLocation2 = '\\sea\eu-pfs\Hotels\Unsecure\Artem\Callidus\'
SET @CmdDir = 'Dir /b /s ' + @FileLocation +'*'

CREATE TABLE #Files(FoundFile VARCHAR(500))
INSERT INTO #Files
EXEC master..xp_cmdshell @CmdDir
SET @Status = @@ERROR

CREATE TABLE #CallidusFiles
(
Original VARCHAR(100),
Callidus VARCHAR(100),
FileID INT
)

INSERT INTO #CallidusFiles
(
Original,
Callidus,
FileID
)
SELECT 'GMM_POSITION_Export.txt','EXPD_OGPO_PRD_'+@DateStamp+'.txt',1
UNION
SELECT 'GMM_FV_Export.txt','EXPD_PLFV_PRD_' +@DateStamp+'.txt',2
UNION
SELECT 'GMM_VA_Export.txt','EXPD_PLVA_PRD_' +@DateStamp+'.txt',3
UNION
SELECT 'GMM_TX_Export.txt','EXPD_TXSTA_PRD_' +@DateStamp+'.txt',4
UNION
SELECT 'GMM_TA_Export.txt','EXPD_TXTA_PRD_' +@DateStamp+'.txt',5

SET @FileID = 0

SET @CmdDelete = 'DEL /Q C:\Callidus\OutGoing\*'
EXEC master..xp_cmdshell @CmdDelete --, NO_OUTPUT

WHILE(@FileID IS NOT NULL)
	BEGIN
		SELECT @FileID = MIN(FileID) FROM #CallidusFiles WHERE FileID > @FileID
		SELECT @FileName = Original,@NewFileName =Callidus FROM #CallidusFiles WHERE FileID = @FileID
		
		SET @CmdRename = 'Rename ' +  @FileLocation + @FileName  +' ' + @NewFileName
		EXEC master..xp_cmdshell @CmdRename --, NO_OUTPUT
		SET @Status =@@ERROR
		--SELECT @Status Statuss,@FileName FileName,@NewFileName NewFileName
	END
		
		IF(@@ERROR<>1)
		BEGIN
			SET @CmdCopy = 'Copy ' + @FileLocation + '*'+@DateStamp + '.txt' + ' ' + 'C:\Callidus\OutGoing\'
			EXEC master..xp_cmdshell @CmdCopy --, NO_OUTPUT
			
			SET @CmdCopy = 'Copy ' + @FileLocation + '*'+@DateStamp + '.txt' + ' ' + @FileLocation2 
			EXEC master..xp_cmdshell @CmdCopy --, NO_OUTPUT
			
		END
