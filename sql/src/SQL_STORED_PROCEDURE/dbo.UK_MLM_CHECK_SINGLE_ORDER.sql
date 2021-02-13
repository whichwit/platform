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
CREATE   procedure [dbo].[UK_MLM_CHECK_SINGLE_ORDER]
(
  @clientguid		numeric(16,0),
  @chartguid		numeric(16,0),
  @clientvisitguid	numeric(16,0),
  @ordername		varchar(200),
  @extraStatus		varchar(200) = 'AUA1'  --KAZ 55FP100014 - add @extraStatus, set default for backward compatibility and makes param optional
)
as
begin

select top 1 o.GUID,o.IDCode  --KAZ 610009 - add o.IDCode
FROM CV3Order o (nolock) 
 inner join CV3OrderCatalogMasterItem ocmi (nolock) 
 on o.OrderCatalogMasterItemGUID = ocmi.GUID 
 inner join CV3OrderStatus os (nolock)
 on o.OrderStatusCode = os.Code 
 where o.ClientGUID = @clientguid
 and o.ClientVisitGUID = @clientvisitguid
 and o.ChartGUID = @chartguid
 and o.Active = 1  
 and charindex(','+o.OrderStatusCode+',',','+@extraStatus+',')>0  --KAZ 55FP100014 - change to @extraStatus
 and ocmi.Name = @ordername;

end