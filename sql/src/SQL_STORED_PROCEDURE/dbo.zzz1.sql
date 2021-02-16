CREATE OR ALTER PROCEDURE dbo.zzz1
--===================================================================
-- Stored procedure:  UK_MLM_CHECK_SINGLE_ORDER
-- Function: check to see if patient already has existing order
-- Parameters:
--		@clientguid			(req) - Patient's client GUID
--		@chartguid			(req) - Patient's chart GUID
--		@clientvisitguid	(req) - Patient's client visit GUID
--		@ordername			(req) - Order item name to search for
--		@extraStatus		(opt) - A comma delimited list of order status names to include in the orders
--									search (ie 'AUA1,PEND').  Must be from the text values listed in CV3OrderStatus.Code.
--									Must be passed in using single quotes on either end of the string.
---------------------------------------------------------------------------------------------------------------------------------------
-- History:
-- Date       	Author    		Description
-- 12/15/2011 	k. guy			new stored procedure for mlm =  UKCMC_CORE_MEASURE_ORDS
-- 05/02/2013	Keith Zomchek	55FP100014 - add @extraStatus to allow more status checks (ie PEND)
-- 07/21/2014	Keith Zomchek	610009 - also return order ID (IDCode)
--===================================================================

(
  @clientguid		NUMERIC(16,0),
  @chartguid		NUMERIC(16,0),
  @clientvisitguid	NUMERIC(16,0),
  @ordername		VARCHAR(200),
  @extraStatus		VARCHAR(200) = 'AUA1  go
  '  --KAZ 55FP100014 - add @extraStatus, set default for backward compatibility and makes param optional
)
AS
BEGIN
  SET ANSI_NULLS ON;
  SET NOCOUNT ON;
  SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

SELECT TOP 1 o.GUID,o.IDCode  --KAZ 610009 - add o.IDCode
FROM CV3Order o
 INNER JOIN CV3OrderCatalogMasterItem ocmi
 ON o.OrderCatalogMasterItemGUID = ocmi.GUID
 INNER JOIN CV3OrderStatus os
 ON o.OrderStatusCode = os.Code
 WHERE o.ClientGUID = @clientguid
 AND o.ClientVisitGUID = @clientvisitguid
 AND o.ChartGUID = @chartguid
 AND o.Active = 1
END
