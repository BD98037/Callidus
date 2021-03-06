USE [SSATools]
GO
/****** Object:  StoredProcedure [dbo].[CALLIDUS_MasterPull]    Script Date: 04/30/2015 14:09:26 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROC [dbo].[CALLIDUS_MasterPull]
@QuarterEnd SmallInt = 0,
@IncludeMAAs SmallInt = 0
AS

/*
[dbo].[CALLIDUS_MasterPull] 1,1
*/

DECLARE @AsOfBookingDate DateTime,@Status Int,@QuarterBegin DateTime

SELECT @AsOfBookingDate = AsOfBookingDate, 
@QuarterBegin = Common.dbo.GetQtrBegin(AsOfBookingDate)
	FROM [CHC-SQLPSG12].ProdReports.[dbo].[KPIPulseData_Callidus]

SELECT @AsOfBookingDate AsOfBookingDate,@QuarterBegin QuarterBegin

		EXEC dbo.CALLIDUS_SetPreqs @QuarterBegin,@QuarterEnd,@IncludeMAAs 
		SET @Status = @@ERROR

		IF(@Status =0)
			BEGIN
				EXEC [dbo].[CALLIDUS_SetTX] 
				SET @Status = @@ERROR
			END
		
		IF(@Status =0)
			BEGIN
				
				EXEC [dbo].[CALLIDUS_SetPosition] @QuarterBegin,@IncludeMAAs
				
				EXEC [dbo].[CALLIDUS_SetFV] @QuarterBegin,@IncludeMAAs 
		
				EXEC [dbo].[CALLIDUS_SetTA] @AsofBookingDate
		
				EXEC [dbo].[CALLIDUS_SetVA] @QuarterBegin
			END
		
	