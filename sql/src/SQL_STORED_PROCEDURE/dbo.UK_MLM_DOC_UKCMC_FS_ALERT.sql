CREATE OR ALTER PROCEDURE [UK_MLM_DOC_UKCMC_FS_ALERT]
/* =============================================
Author:		Le Yang
Create date: 2018-03-05
Description:	Return clinical validation alert
------------------------------------------------
2018-03-22  LY  WO0000000136104
Trach alert criteria change:
    - Only "no sutures present" tube care entry can suppress alert
    - If "no sutures present" is documented in any time column after insertion date, an alert should not fire
------------------------------------------------
2018-03-28  LY  WO0000000136992
Only alert for foley and trach for active patients.
------------------------------------------------
2019-10-03  LY  WO0000000270850
Suicide Severity Reassessment Warning: If the LAST documented value for any of these observations is "No", we
want the alert to popup and tell them to reassess the patient using the columbia suicide screening tool.
------------------------------------------------
2020-05-27  LY  RITM0011965
One-time alert on previous COVID screening
------------------------------------------------
2020-06-25  LY  RITM0017635
New COVID observation `covid 19 pos test y/n` to capture previous exposure
==============================================*/
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

    DECLARE @LF CHAR = CHAR(10)
    DECLARE @CR CHAR = CHAR(13)

    DECLARE @caption VARCHAR(255)
    DECLARE @text1 VARCHAR(4000), @text2 VARCHAR(4000)
    DECLARE @datetime1 DATETIME, @datetime2 DATETIME
    DECLARE @bit1 BIT

    IF NOT EXISTS (
        SELECT *
        FROM CV3ClientVisit
        WHERE ClientGUID = @ClientGUID
            AND GUID = @VisitGUID
            AND VisitStatus = 'ADM'
    ) RETURN

    DECLARE @Alert TABLE (
        Caption VARCHAR(50)
        , Message VARCHAR(1000)
        , ButtonType VARCHAR(25) DEFAULT 'OK'
        , ImageType VARCHAR(25) DEFAULT 'Warning'  -- information, question, stop, warning
    )

    DECLARE @Observation TABLE (
        ObservationDocumentGUID HVCIDdt
        , Name VARCHAR(255)
        , ObsMasterItemGUID HVCIDdt
        , RecordedDtm DATETIME
        , CreatedDtm DATETIME
        , Value VARCHAR(255)
        , ValidValueGUID HVCIDdt
        , PatCareDocGUID HVCIDdt
        , ClientDocumentGUID HVCIDdt
        , ParameterGUID HVCIDdt
        , ObsItemGUID HVCIDdt
        , INDEX idx_cl (Name, Value)
    )

    INSERT @Observation
	SELECT
        op.ObservationDocumentGUID
        , ocmi.Name
        , ocmi.GUID AS ObsMasterItemGUID
        , op.RecordedDtm
        , op.CreatedWhen
        , COALESCE(op.ValueTExt, fsv.Value) AS Value
        , fsv.ValidValueGUID
        , PatCareDocGUID
        , op.OwnerGUID AS ClientDocumentGUID
        , op.ParameterGUID
        , op.ObsItemGUID
    FROM CV3ObsCatalogMasterItem ocmi
    CROSS APPLY (
        SELECT TOP(1) op.*
        FROM SXACDObservationParameter op
        JOIN CV3Observation o ON o.GUID = op.ObservationGUID
            AND op.OwnerGUID = o.FirstDocGUID
        WHERE op.ClientGUID = @ClientGUID
            AND op.ChartGUID = @ChartGUID
            AND op.ObsMasterItemGUID = ocmi.GUID
        ORDER BY op.RecordedDtm DESC, op.CreatedWhen DESC
    ) op
    LEFT JOIN SCMObsFSListValues fsv ON fsv.ClientGUID = op.ClientGUID
        AND fsv.ParentGUID = op.ObservationDocumentGUID
    WHERE ocmi.Name IN (
        'AS airway type'
        , 'uk trach insertion DT'
        , 'uk foley status ssr'
        , 'uk urethral cath insertion DT'
        , 'uk urethral cath change DT V2'
        , 'NRSG Adult Assess'
        , 'NRSG Ped Assess'
        , 'NRSG Assess Freq'
        , 'nrsg colum severity'
    )

    UNION

    SELECT
        op.ObservationDocumentGUID
        , ocmi.Name
        , ocmi.GUID AS ObsMasterItemGUID
        , op.RecordedDtm
        , op.CreatedWhen
        , COALESCE(op.ValueTExt, fsv.Value) AS Value
        , fsv.ValidValueGUID
        , PatCareDocGUID
        , op.OwnerGUID AS ClientDocumentGUID
        , op.ParameterGUID
        , op.ObsItemGUID
    FROM CV3ObsCatalogMasterItem ocmi
    CROSS APPLY (
        SELECT op.*
        FROM SXACDObservationParameter op
        JOIN CV3Observation o ON o.GUID = op.ObservationGUID
            AND op.OwnerGUID = o.FirstDocGUID
        WHERE op.ClientGUID = @ClientGUID
            AND op.ChartGUID = @ChartGUID
            AND op.ObsMasterItemGUID = ocmi.GUID
    ) op
    LEFT JOIN SCMObsFSListValues fsv ON fsv.ClientGUID = op.ClientGUID
        AND fsv.ParentGUID = op.ObservationDocumentGUID
    WHERE ocmi.Name IN (
        'AS airway tube care'
    )

    IF @Debug = 1 SELECT '@Observation', * FROM @Observation

    DECLARE @Order TABLE (
        OrderCatalogMasterItemGUID HVCIDdt
        , Name VARCHAR(255)
        , OrderGUID HVCIDdt
        , SignificantDtm DATETIME
        , CreatedDtm DATETIME
        , OrderStatusCode VARCHAR(5)
        , OrderStatusLevelNum INT
        , INDEX idx_cl (Name)
    )

    INSERT @Order (OrderCatalogMasterItemGUID, Name, OrderGUID, SignificantDtm, CreatedDtm, OrderStatusCode, OrderStatusLevelNum)
    SELECT
        o.OrderCatalogMasterItemGUID
        , ocmi.Name
        , o.GUID
        , o.SignificantDtm
        , o.Entered
        , o.OrderStatusCode
        , o.OrderStatusLevelNum
    FROM CV3OrderCatalogMasterItem ocmi
    CROSS APPLY (
        SELECT *
        FROM CV3Order o
        WHERE o.ClientGUID = @ClientGUID
            AND o.ChartGUID = @ChartGUID
            AND o.OrderCatalogMasterItemGUID = ocmi.GUID
            AND o.OrderStatusLevelNum IN (45,50)
    ) AS o
    WHERE ocmi.Name IN (
        'Urine Culture (Catheter Urine)'
        , 'Urine Culture (Clean Catch)'
        , 'UA with Microscopic Reflex'
        , 'Foley to Straight Drain'
    )

    IF @Debug = 1 SELECT '@Order', * FROM @Order

    -- ----------------------------------------
    -- Suicide Severity Reassessment Warning
    -- ----------------------------------------
    IF @EventType = 'DocumentOpening'
    BEGIN
        -- check for last observation qualifying for alert
        SET @bit1 = NULL
        SET @datetime1 = NULL
        SET @text1 = NULL

        ;WITH a AS (
            SELECT TOP 1
                o.Value
                , o.RecordedDtm
            FROM @Observation o
            WHERE o.Name = 'nrsg colum severity'
            ORDER BY o.RecordedDtm DESC
        )
        , b AS (
            SELECT TOP 1
                o.Value
                , o.RecordedDtm
            FROM @Observation o
            WHERE o.Name IN ('NRSG Adult Assess'
                , 'NRSG Ped Assess'
                , 'NRSG Assess Freq'
            )
            ORDER BY o.RecordedDtm DESC
        )
        , o AS (
            SELECT * FROM a
            UNION
            SELECT * FROM b
        )
        SELECT TOP 1
            @text1 = o.Value
            , @datetime1 = o.RecordedDtm
        FROM o
        ORDER BY o.RecordedDtm DESC

        -- qualifying result
        IF @text1 IN ('no','low','moderate','high')
        BEGIN
            SET @text2 = 'CSSR Reassess'
            SET @datetime2 = (
                SELECT TOP 1
                    CONVERT(DATETIME, ModifiedDtm)
                FROM UKCustomData
                WHERE Namespace = 'Internal'
                    AND Code = 'FlowsheetAlertLogging'
                    AND Value = @text2
                    AND Active = 1
                    AND ClientGUID = @ClientGUID
                    AND VisitGUID = @VisitGUID
                    AND UserGUID = @UserGUID
                ORDER BY ModifiedDtm DESC
            )

            IF GETDATE() >= DATEADD(HOUR, CEILING(DATEDIFF(HOUR, @datetime1, COALESCE(@datetime2, DATEADD(HOUR,1,@datetime1))) / 12.0) * 12, @datetime1)
            BEGIN
                INSERT @Alert (Caption, Message)
                VALUES (@text2,'Reassess the patient using the Columbia suicide screening tool')
            END
        END

    /*
        DECLARE @norisk TINYINT = 0
        DECLARE @text1 VARCHAR(50), @datetime1 DATETIME, @suicide BIT = 0

        SELECT TOP 1
            @text1 = o.Value,
            @datetime1 = o.CreatedDtm
        FROM @Observation o
        WHERE o.Name = 'nrsg colum severity'
        ORDER BY o.CreatedDtm DESC

        IF @text1 IN ('low','moderate','high')
        BEGIN
            SET @suicide = 1
        END

        ;WITH o AS (
            SELECT TOP 2
                o.Value
            FROM @Observation o
            WHERE o.Name = 'nrsg colum severity'
            ORDER BY o.CreatedDtm DESC
        )
        SELECT @norisk = COUNT(*)
        FROM o
        WHERE o.Value = 'no risk'

        IF @norisk < 2
        BEGIN
            IF @suicide = 0
            BEGIN
                SELECT TOP 1
                    @text1 = o.Value,
                    @datetime1 = o.CreatedDtm
                    FROM @Observation o
                    WHERE o.Name IN ('NRSG Adult Assess','NRSG Ped Assess','NRSG Assess Freq')
                    ORDER BY o.CreatedDtm DESC

                IF @text1 = 'No' SET @suicide = 1
            END

            IF @suicide = 1
            BEGIN
                INSERT @Alert (Caption, Message)
                VALUES ('Alert', 'Reassess the patient using the Columbia suicide screening tool')
            END
        END
        */
    END


    -- ----------------------------------------
    -- Trach Suture Removal Alert
    -- ----------------------------------------
    IF @EventType = 'DocumentOpening'
        AND NOT EXISTS (
            SELECT *
            FROM CV3ClientVisit cv
            JOIN CV3Location l ON l.GUID = cv.CurrentLocationGUID
                AND l.LevelCode IN (
                    'SS3BC'
                    ,'H3NEO'
                    ,'H4E'
                    ,'H4NCU'
                    ,'H4NIC'
                    ,'H4PCU'
                    ,'H4PIC'
                    ,'H4W'
                    ,'HCSPU'
                    ,'HNICU'
                    ,'H6E'
                    ,'H4N'
                    ,'H4OUT'
                    ,'H4S'
                    ,'H3NUR'
                )
            WHERE cv.ClientGUID = @ClientGUID
                AND cv.GUID = @VisitGUID
        )
        AND EXISTS (
            SELECT *
            FROM @Observation o
            WHERE o.Name = 'AS airway type'
                AND o.Value IN ('tracheostomy','tracheostomy with sutures')
        ) AND EXISTS (
            SELECT *
            FROM @Observation o
            WHERE o.Name = 'uk trach insertion DT'
                AND DATEDIFF(DAY,CONVERT(DATE, o.Value),GETDATE()) > 1 -- day 1 is the date of insertion
                AND NOT EXISTS (
                    SELECT *
                    FROM @Observation o2
                    WHERE o2.Name = 'AS airway tube care'
                        AND o2.Value = 'no sutures present'
                        AND o2.RecordedDtm >= o.RecordedDtm
                )
        )
    BEGIN
        INSERT @Alert (Caption, Message)
        VALUES ('Tracheostomy Suture Removal Alert', 'Trach Day 3: Please remove sutures from trach.'+@LF+@LF+'For ENT patients: Please DO NOT remove trach sutures or ties unless OK with the ENT team.')
    END

    -- ----------------------------------------
    -- COVID Screening
    -- ----------------------------------------
    SET @caption = 'COVID Screening COMPLETE'
    IF @EventType = 'DocumentOpening'
        AND @DocumentName IN (
            '1. Patient Care Flowsheet'
            , '1. Pediatric Patient Care Flowsheet'
            , '1. OB Patient Care Flowsheet'
            , '01. GSH BH Patient Care Flowsheet'
            , '1. OB CPN Flowsheet'
        )
        AND NOT EXISTS (
            SELECT *
            FROM UKCustomData
            WHERE Namespace = 'Internal'
                AND Code = 'FlowsheetAlertLogging'
                AND Value = @caption
                AND UserGUID = @UserGUID
                AND ClientGUID = @ClientGUID
                AND ChartGUID = @ChartGUID
                AND VisitGUID = @VisitGUID
        )
    BEGIN
        DECLARE @covidTmp TABLE (
            DocumentName VARCHAR(255)
            , SignificantDtm DATETIME
            , Text VARCHAR(2000)
            , IsFirstDocument BIT
        )

        INSERT @covidTmp
        SELECT op.PatientCareDocumentName
            , op.RecordedDtm
            , CONCAT(
                CASE ocmi.Name
                    WHEN 'covid 19 fever y/n' THEN 'Fever?'
                    WHEN 'covid 19 sob y/n' THEN 'Sob?'
                    WHEN 'covid 19 cough y/n' THEN 'Cough?'
                    WHEN 'covid 19 unresponsive y/n' THEN 'Unresponsive/Altered Mental Status?'
                    WHEN 'COVID 19 chills y/n' THEN 'Chills?'
                    WHEN 'COVID 19 sore throat y/n' THEN 'Sore Throat?'
                    WHEN 'COVID 19 loss of taste/smell y/n' THEN 'Loss of Taste/Smell?'
                    WHEN 'COVID 19 body aches y/n' THEN 'Body Aches?'
                    WHEN 'covid 19 pos test y/n' THEN 'Positive or Exposure?'
                END
                , '  =  '
                , fsv.Value
            )
            , CASE
                WHEN op.OwnerGUID = op.FirstDocGUID THEN 1
                ELSE 0
            END
        FROM CV3ObsCatalogMasterItem ocmi
        CROSS APPLY (
            SELECT TOP(1) op.*
                , pcd.Name AS PatientCareDocumentName
                , o.FirstDocGUID
            FROM SXACDObservationParameter op
            JOIN CV3Observation o ON o.GUID = op.ObservationGUID
            JOIN CV3PatientCareDocument pcd ON pcd.GUID = op.PatCareDocGUID
            WHERE op.ObsMasterItemGUID = ocmi.GUID
                AND op.ClientGUID = @ClientGUID
                AND op.ChartGUID = @ChartGUID
                AND op.ClientVisitGUID = @VisitGUID
            ORDER BY op.RecordedDtm DESC, op.CreatedWhen DESC
        ) op
        CROSS APPLY (
            SELECT TOP 1 SFS.Value
            FROM SCMObsFSListValues sfs
            WHERE sfs.Active = 1
                AND sfs.ClientGUID = op.ClientGUID
                AND sfs.ParentGUID = op.ObservationDocumentGUID
            ORDER BY
                sfs.SortSeqNum
        ) fsv (Value)
        OUTER APPLY (
            SELECT TOP(1)
                p.*
            FROM CV3ObservationEntryItem p
            WHERE p.GUID = op.ParameterGUID
        ) AS p
        WHERE ocmi.Name IN (
            'covid 19 cough y/n'
	        , 'covid 19 sob y/n'
	        , 'covid 19 fever y/n'
	        , 'covid 19 unresponsive y/n'
	        , 'covid 19 sore throat y/n'
	        , 'covid 19 chills y/n'
	        , 'covid 19 loss of taste/smell y/n'
	        , 'covid 19 body aches y/n'
            , 'covid 19 pos test y/n'
        )
        ORDER BY p.DisplaySequence

        SET @datetime1 = (SELECT TOP 1 SignificantDtm FROM @covidTmp) -- chart date/time
        SET @text2 = (SELECT TOP 1 DocumentName FROM @covidTmp) -- documented source
        SET @text1 = (
            SELECT Text+'
'
            FROM @covidTmp
            WHERE IsFirstDocument = 1
            FOR XML PATH('')
        )

        IF @Debug = 1 SELECT 'COVID SCREENING TEXT', @text1

        IF @text1 IS NOT NULL
            AND NOT EXISTS (
                SELECT *
                FROM @covidTmp
                WHERE DocumentName = @DocumentName
            )
        BEGIN
            INSERT @Alert (ImageType, Caption, Message)
            VALUES ('Information', @caption, CONCAT(
                'The patient was screened this visit on '
                , FORMAT(@datetime1, 'dd-MMM-yyyy HH:mm')
                , ' using the '
                , @text2
                , ':

'
                , REPLACE(@text1,'&#x0D;','')
            ))
        END
    END

    -- ----------------------------------------
    -- Foley Change Alert
    -- ----------------------------------------
    IF @EventType = 'DocumentOpening'
        AND EXISTS (
            SELECT *
            FROM @Observation o
            WHERE o.Name = 'uk foley status ssr'
                AND o.Value IN ('inserted','present on arrival','in place')
        ) AND NOT EXISTS (
            SELECT *
            FROM @Observation o
            WHERE o.Name IN ('uk urethral cath insertion DT','uk urethral cath change DT V2')
                AND CONVERT(DATE, o.Value) > DATEADD(DAY, -5+1, CONVERT(DATE,GETDATE())) -- day 1 is the date of insertion
        ) AND EXISTS (
            SELECT *
            FROM @Order o
            WHERE o.Name IN ('Urine Culture (Catheter Urine)', 'Urine Culture (Clean Catch)', 'UA with Microscopic Reflex')
        )
    BEGIN
        INSERT @Alert (Caption, Message)
        VALUES ('Foley Change Alert', 'Your patient''s Foley catheter has been in place for 5 or more days. Please change catheter prior to collecting urinalysis and/or urine culture, unless contraindicated or patient has active "opt-out" order.')
    END

    -- ----------------------------------------
    -- Foley Order Missing Alert
    -- ----------------------------------------
    IF @EventType = 'ChartObservation'
        AND NOT EXISTS (
            SELECT *
            FROM @Order o
            WHERE o.Name = 'Foley to Straight Drain'
        )
        AND @ParameterName = 'uk foley status ssr'
        AND @Value IN ('inserted','present on arrival','in place')
        AND DATEPART(Hour, @DateTime) % 4 = 0
        AND DATEPART(Minute, @DateTime) = 0
    BEGIN
        INSERT @Alert (Caption, Message)
        VALUES ('Foley Order Missing Alert', 'Patient does not have an active "foley to straight drain" order, please discuss with the provider.')
    END

    -- ----------------------------------------
    -- LOGGING
    -- ----------------------------------------
    INSERT UKCustomData (ClientGUID, ChartGUID, VisitGUID, Namespace, Code, Value, ValueText, ValueDateTime, ObjectName, ObjectGUID, UserGUID )
    SELECT @ClientGUID
        , @ChartGUID
        , @VisitGUID
        , 'Internal'
        , 'FlowsheetAlertLogging'
        , Caption
        , Message
        , TODATETIMEOFFSET(@DateTime, DATEPART(TZOFFSET, SYSDATETIMEOFFSET()))
        , @ParameterName
        , @ParameterGUID
        , @UserGUID
    FROM @Alert

    -- ----------------------------------------
    -- FINAL RETURN
    -- ----------------------------------------
    SELECT Caption, Message, ButtonType, ImageType FROM @Alert
END