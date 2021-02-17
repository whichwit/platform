CREATE OR ALTER PROCEDURE zzz2
	@ClientGUID HVCIDdt,
    @ChartGUID HVCIDdt,
	@VisitGUID HVCIDdt,
    @EventType VARCHAR(25) = 'DocumentOpening', -- DocumentOpening, ChartObservation, DocumentClosing, AutoEnter
    @DateTime DATETIME = NULL,
    @ParameterGUID HVCIDdt = NULL,
    @ParameterName VARCHAR(250) = NULL,
    @ParameterDataType VARCHAR(25) = NULL,
    @Value VARCHAR(250) = NULL,
    @DisplaySequence INT = NULL,
    @Debug BIT = 0,
    @UserGUID HVCIDdt = NULL,
    @DocumentName VARCHAR(255) = NULL
AS
BEGIN
	SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED ;

    SELECT GETDATE()       ;
END