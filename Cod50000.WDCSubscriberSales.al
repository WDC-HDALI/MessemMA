codeunit 50000 "WDC Subscriber Sales"
{

    [EventSubscriber(ObjectType::Table, database::"sales Line", 'OnAfterAssignFieldsForNo', '', FALSE, FALSE)]
    local procedure OnAfterAssignFieldsForNosales(var SalesLine: Record "Sales Line"; var xSalesLine: Record "Sales Line"; SalesHeader: Record "Sales Header")


    begin
        item.reset();
        if Item.get(SalesLine."No.") then
            SalesLine."Packaging Item" := IsPackagingItem();
        IF NOT SalesLine."Packaging Item" THEN BEGIN
            SalesLine."Shipment Unit" := Item."Shipment Unit";
            SalesLine."Shipment Container" := Item."Shipment Container";
            if item."Shipm.Units per Shipm.Containr" <> 0 then
                SalesLine."Qty Shipm.Units per Shipm.Cont" := item."Shipm.Units per Shipm.Containr"
            else
                SalesLine."Qty Shipm.Units per Shipm.Cont" := 1
        END ELSE BEGIN
            SalesLine."Shipment Unit" := '';
            SalesLine."Shipment Container" := '';
        END;
        IF SalesLine."Shipment Unit" <> '' THEN
            SalesLine."Qty. per Shipment Unit" := Item."Qty. per Shipment Unit" / SalesLine."Qty. per Unit of Measure"
        ELSE
            SalesLine."Qty. per Shipment Unit" := 1;
        IF SalesLine."Shipment Container" <> '' THEN
            SalesLine."Qty. per Shipment Container" := Item."Qty. per Shipment Container" / SalesLine."Qty. per Unit of Measure"
        ELSE
            SalesLine."Qty. per Shipment Container" := 1;
        SalesLine."Harmonised Tariff Code" := Item."GTIN";//WDC.HG

    end;

    [EventSubscriber(ObjectType::Table, database::"sales line", 'OnValidateQuantityOnAfterCalcBaseQty', '', FALSE, FALSE)]
    local procedure OnValidateQuantityOnAfterCalcBaseQtysale(var SalesLine: Record "Sales Line"; xSalesLine: Record "Sales Line")
    begin
        IF SalesLine."Shipment Unit" <> '' THEN
            SalesLine."Quantity Shipment Units" := ROUND(SalesLine.Quantity / SalesLine."Qty. per Shipment Unit", 1, '>');
        IF SalesLine."Shipment Container" <> '' THEN begin
            SalesLine."Quantity Shipment Containers" := ROUND(SalesLine.Quantity / SalesLine."Qty. per Shipment Container", 1, '>');
            IF SalesLine."Qty. per Shipment Container" <> 0 THEN
                SalesLine."Qty. Shpt. Cont. Calc." := SalesLine.Quantity / SalesLine."Qty. per Shipment Container";
        end;
    end;

    [EventSubscriber(ObjectType::Table, database::"sales line", 'OnInitQtyToShipOnBeforeCheckServItemCreation', '', FALSE, FALSE)]
    local procedure OnInitQtyToShipOnBeforeCheckServItemCreation(var SalesLine: Record "Sales Line")

    begin
        SalesSetup.Get();
        if (SalesSetup."Default Quantity to Ship" = SalesSetup."Default Quantity to Ship"::Remainder) or
           (SalesLine."Document Type" = SalesLine."Document Type"::Invoice)
        then begin
            if Not (SalesLine."Outstanding Quantity" = 0) then begin
                SalesLine."Qty. to Ship Shipment Units" := SalesLine."Quantity Shipment Units" -
                (SalesLine."Qty. Shipped Shipment Units" + SalesLine."Reserv Qty. to Post Ship.Unit");
                SalesLine."Qty. to Ship Shipm. Containers" := SalesLine."Quantity Shipment Containers" -
                  (SalesLine."Qty. Shipped Shipm. Containers" + SalesLine."Reserv Qty. to Post Ship.Cont.");
            end;

        end;
    end;

    [EventSubscriber(ObjectType::Table, database::"sales line", 'OnBeforeCalcInvDiscToInvoice', '', FALSE, FALSE)]
    local procedure OnBeforeCalcInvDiscToInvoice(var SalesLine: Record "Sales Line"; CallingFieldNo: Integer)
    begin
        SalesLine."Qty. S.Units to invoice" := MaxShipUnitsToInvoice(SalesLine);
        SalesLine."Qty. S.Cont. to invoice" := MaxShipContToInvoice(SalesLine);
    end;

    [EventSubscriber(ObjectType::Table, database::"sales line", 'OnAfterUpdateWithWarehouseShip', '', FALSE, FALSE)]
    local procedure OnAfterUpdateWithWarehouseShip(SalesHeader: Record "Sales Header"; var SalesLine: Record "Sales Line")
    var
        Location: Record "Location";
    begin
        if Item.get(SalesLine."No.") then
            SalesLine."Packaging Item" := IsPackagingItem();
        IF (SalesLine.Type = SalesLine.Type::Item) THEN
            CASE TRUE OF
                (SalesLine."Document Type" IN [SalesLine."Document Type"::Quote, SalesLine."Document Type"::Order]) AND (SalesLine.Quantity >= 0):
                    IF (Location.RequireShipment(SalesLine."Location Code")) AND NOT SalesLine."Packaging Item" THEN BEGIN
                        SalesLine.VALIDATE(SalesLine."Qty. to Ship Shipment Units", 0);
                        SalesLine.VALIDATE(SalesLine."Qty. to Ship Shipm. Containers", 0);
                    END ELSE BEGIN
                        IF NOT (SalesLine."Outstanding Quantity" = 0) THEN BEGIN
                            SalesLine.VALIDATE(SalesLine."Qty. to Ship Shipment Units", SalesLine."Quantity Shipment Units" -
                              (SalesLine."Qty. Shipped Shipment Units" + SalesLine."Reserv Qty. to Post Ship.Unit"));
                            SalesLine.VALIDATE(SalesLine."Qty. to Ship Shipm. Containers", SalesLine."Quantity Shipment Containers" -
                              (SalesLine."Qty. Shipped Shipm. Containers" + SalesLine."Reserv Qty. to Post Ship.Cont."));
                        END ELSE BEGIN
                            SalesLine.VALIDATE(SalesLine."Qty. to Ship Shipment Units", 0);
                            SalesLine.VALIDATE(SalesLine."Qty. to Ship Shipm. Containers", 0);
                        END;
                    END;
                (SalesLine."Document Type" IN [SalesLine."Document Type"::Quote, SalesLine."Document Type"::Order]) AND (SalesLine.Quantity < 0):
                    IF Location.RequireReceive(SalesLine."Location Code") THEN BEGIN
                        SalesLine.VALIDATE(SalesLine."Qty. to Ship Shipment Units", 0);
                        SalesLine.VALIDATE(SalesLine."Qty. to Ship Shipm. Containers", 0);
                    END ELSE BEGIN
                        IF NOT (SalesLine."Outstanding Quantity" = 0) THEN BEGIN
                            SalesLine.VALIDATE(SalesLine."Qty. to Ship Shipment Units", SalesLine."Quantity Shipment Units" -
                              (SalesLine."Qty. Shipped Shipment Units" + SalesLine."Reserv Qty. to Post Ship.Unit"));
                            SalesLine.VALIDATE(SalesLine."Qty. to Ship Shipm. Containers", SalesLine."Quantity Shipment Containers" -
                              (SalesLine."Qty. Shipped Shipm. Containers" + SalesLine."Reserv Qty. to Post Ship.Cont."));
                        END ELSE BEGIN
                            SalesLine.VALIDATE(SalesLine."Qty. to Ship Shipment Units", 0);
                            SalesLine.VALIDATE(SalesLine."Qty. to Ship Shipm. Containers", 0);
                        END;
                    END;
                (SalesLine."Document Type" = SalesLine."Document Type"::"Return Order") AND (SalesLine.Quantity >= 0):
                    IF (Location.RequireReceive(SalesLine."Location Code")) AND NOT (SalesLine."Packaging Item") THEN BEGIN
                        SalesLine.VALIDATE(SalesLine."Return Qty. to Receive S.Units", 0);
                        SalesLine.VALIDATE(SalesLine."Return Qty. to Receive S.Cont.", 0);
                    END ELSE BEGIN
                        IF NOT (SalesLine."Outstanding Quantity" = 0) then begin
                            SalesLine.VALIDATE(SalesLine."Return Qty. to Receive S.Units", SalesLine."Quantity Shipment Units" -
                              (SalesLine."Return Qty. Received S.Units" + SalesLine."Reserv Qty. to Post Ship.Unit"));
                            SalesLine.VALIDATE(SalesLine."Return Qty. to Receive S.Cont.", SalesLine."Quantity Shipment Containers" -
                              (SalesLine."Return Qty. Received S.Cont." + SalesLine."Reserv Qty. to Post Ship.Cont."));
                        END ELSE BEGIN
                            SalesLine.VALIDATE(SalesLine."Return Qty. to Receive S.Units", 0);
                            SalesLine.VALIDATE(SalesLine."Return Qty. to Receive S.Cont.", 0);
                        END;
                    END;
                (SalesLine."Document Type" = SalesLine."Document Type"::"Return Order") AND (SalesLine.Quantity < 0):
                    IF (Location.RequireShipment(SalesLine."Location Code")) AND NOT (SalesLine."Packaging Item") THEN BEGIN
                        SalesLine.VALIDATE(SalesLine."Return Qty. to Receive S.Units", 0);
                        SalesLine.VALIDATE(SalesLine."Return Qty. to Receive S.Cont.", 0);
                    END ELSE BEGIN
                        IF NOT (SalesLine."Outstanding Quantity" = 0) then begin
                            SalesLine.VALIDATE(SalesLine."Return Qty. to Receive S.Units", SalesLine."Quantity Shipment Units" -
                              (SalesLine."Return Qty. Received S.Units" + SalesLine."Reserv Qty. to Post Ship.Unit"));
                            SalesLine.VALIDATE(SalesLine."Return Qty. to Receive S.Cont.", SalesLine."Quantity Shipment Containers" -
                              (SalesLine."Return Qty. Received S.Cont." + SalesLine."Reserv Qty. to Post Ship.Cont."));
                        END ELSE BEGIN
                            SalesLine.VALIDATE(SalesLine."Return Qty. to Receive S.Units", 0);
                            SalesLine.VALIDATE(SalesLine."Return Qty. to Receive S.Cont.", 0);
                        END;
                    END;
            END;
        //
    end;

    [EventSubscriber(ObjectType::Table, database::"sales line", 'OnAfterInitQtyToInvoice', '', FALSE, FALSE)]
    local procedure OnAfterInitQtyToInvoice(var SalesLine: Record "Sales Line"; CurrFieldNo: Integer)
    begin
        SalesLine."Qty. S.Units to invoice" := MaxShipUnitsToInvoice(SalesLine);
        SalesLine."Qty. S.Cont. to invoice" := MaxShipContToInvoice(SalesLine);
    end;

    [EventSubscriber(ObjectType::Table, database::"sales line", 'OnBeforeUpdateQtyToAsmFromSalesLineQtyToShip', '', FALSE, FALSE)]
    local procedure OnBeforeUpdateQtyToAsmFromSalesLineQtyToShip(var SalesLine: Record "Sales Line"; var IsHandled: Boolean)
    begin
        SalesLine.CalcPackagingQuantityToShip;
    end;

    [EventSubscriber(ObjectType::Table, database::"sales line", 'OnBeforeCheckApplFromItemLedgEntry', '', FALSE, FALSE)]
    local procedure OnBeforeCheckApplFromItemLedgEntry(var SalesLine: Record "Sales Line"; xSalesLine: Record "Sales Line"; var ItemLedgerEntry: Record "Item Ledger Entry"; var IsHandled: Boolean)
    begin
        SalesLine.CalcPackagingQuantityToShip;
    end;

    [EventSubscriber(ObjectType::Table, database::"sales line", 'OnValidateQtyToReturnAfterInitQty', '', FALSE, FALSE)]
    local procedure OnValidateQtyToReturnAfterInitQty(var SalesLine: Record "Sales Line"; var xSalesLine: Record "Sales Line"; CallingFieldNo: Integer; var IsHandled: Boolean)
    begin
        SalesLine.CalcPackagingQuantityToShip
    end;
    //validation sales order
    [EventSubscriber(ObjectType::Table, database::"Sales Shipment Line", 'OnAfterInitFromSalesLine', '', FALSE, FALSE)]
    local procedure OnAfterInitFromSalesLine(SalesShptHeader: Record "Sales Shipment Header"; SalesLine: Record "Sales Line"; var SalesShptLine: Record "Sales Shipment Line")
    begin
        SalesShptLine."Quantity Shipment Units" := SalesLine."Reserv Qty. to Post Ship.Unit";
        SalesShptLine."Quantity Shipment Containers" := SalesLine."Reserv Qty. to Post Ship.Cont.";
    end;

    [EventSubscriber(ObjectType::Codeunit, codeunit::"Sales-Post", 'OnCodeOnBeforeFillTempLines', '', FALSE, FALSE)]
    local procedure OnCodeOnBeforeFillTempLines(var SalesHeader: Record "Sales Header"; CalledBy: Integer)
    begin
        IF SalesHeader."Document Type" IN [SalesHeader."Document Type"::Order, SalesHeader."Document Type"::"Return Order",
                                            SalesHeader."Document Type"::Invoice, SalesHeader."Document Type"::"Credit Memo"]
         THEN
            AddOrderPackaging(SalesHeader);
        AddCustomerPackaging(SalesHeader);

    end;


    [EventSubscriber(ObjectType::Codeunit, codeunit::"Sales-Post", 'OnBeforeInitSalesLineQtyToInvoice', '', FALSE, FALSE)]

    local procedure OnBeforeInitSalesLineQtyToInvoice(var SalesHeader: Record "Sales Header"; var SalesLine: Record "Sales Line"; var IsHandled: Boolean)
    begin
        IF (SalesHeader."Document Type" = SalesHeader."Document Type"::Invoice) AND (SalesLine."Shipment No." <> '') THEN BEGIN
            SalesLine."Qty. Shipped Shipment Units" := SalesLine."Quantity Shipment Units";
            SalesLine."Qty. Shipped Shipm. Containers" := SalesLine."Quantity Shipment Containers";
            SalesLine."Reserv Qty. to Post Ship.Unit" := 0;
            SalesLine."Reserv Qty. to Post Ship.Cont." := 0;
        end;
        if (SalesHeader."Document Type" = SalesHeader."Document Type"::"Credit Memo") and (SalesLine."Return Receipt No." <> '') then begin
            SalesLine."Return Qty. Received S.Units" := SalesLine."Quantity Shipment Units";
            SalesLine."Return Qty. Received S.Cont." := SalesLine."Quantity Shipment Containers";
            SalesLine."Reserv Qty. to Post Ship.Unit" := 0;
            SalesLine."Reserv Qty. to Post Ship.Cont." := 0;
        end;

    end;
    //
    //rverse amount 
    [EventSubscriber(ObjectType::Codeunit, codeunit::"Sales-Post", 'OnPostSalesLineOnBeforePostItemTrackingLine', '', FALSE, FALSE)]

    local procedure OnPostSalesLineOnBeforePostItemTrackingLine(var SalesHeader: Record "Sales Header"; var SalesLine: Record "Sales Line"; WhseShip: Boolean; WhseReceive: Boolean; InvtPickPutaway: Boolean; SalesInvHeader: Record "Sales Invoice Header"; SalesCrMemoHeader: Record "Sales Cr.Memo Header"; var ItemLedgShptEntryNo: Integer; var RemQtyToBeInvoiced: Decimal; var RemQtyToBeInvoicedBase: Decimal; GenJnlLineDocNo: Code[20]; SrcCode: Code[10]; var ItemJnlPostLine: Codeunit "Item Jnl.-Post Line")
    begin
        if not (SalesHeader."Document Type" in [SalesHeader."Document Type"::"Return Order", SalesHeader."Document Type"::"Credit Memo"]) then begin
            SalesLine."Reserv Qty. to Post Ship.Unit" := -SalesLine."Reserv Qty. to Post Ship.Unit";
            SalesLine."Reserv Qty. to Post Ship.Cont." := -SalesLine."Reserv Qty. to Post Ship.Cont.";
        end

    end;

    [EventSubscriber(ObjectType::Codeunit, codeunit::"Sales-Post", 'OnPostUpdateOrderLineOnBeforeSetInvoiceFields', '', FALSE, FALSE)]
    local procedure OnPostUpdateOrderLineOnBeforeSetInvoiceFields(var SalesHeader: Record "Sales Header"; var TempSalesLine: Record "Sales Line"; var ShouldSetInvoiceFields: Boolean)
    begin
        if SalesHeader.Ship then begin
            TempSalesLine."Qty. Shipped Shipment Units" += TempSalesLine."Reserv Qty. to Post Ship.Unit";
            TempSalesLine."Qty. Shipped Shipm. Containers" += TempSalesLine."Reserv Qty. to Post Ship.Cont.";
        end;
        if SalesHeader.Receive then begin
            TempSalesLine."Return Qty. Received S.Units" += TempSalesLine."Reserv Qty. to Post Ship.Unit";
            TempSalesLine."Return Qty. Received S.Cont." += TempSalesLine."Reserv Qty. to Post Ship.Cont.";
        end;

    end;

    [EventSubscriber(ObjectType::Table, database::"item journal line", 'OnAfterCopyItemJnlLineFromSalesLine', '', FALSE, FALSE)]
    local procedure OnAfterCopyItemJnlLineFromSalesLine(var ItemJnlLine: Record "Item Journal Line"; SalesLine: Record "Sales Line")
    begin
        ItemJnlLine."Shipment Unit" := SalesLine."Shipment Unit";
        ItemJnlLine."Shipment Container" := SalesLine."Shipment Container";
        ItemJnlLine."Quantity Shipment Units" := SalesLine."Reserv Qty. to Post Ship.Unit";
        ItemJnlLine."Quantity Shipment Containers" := SalesLine."Reserv Qty. to Post Ship.Cont.";
        ItemJnlLine."Qty Shipm.Units per Shipm.Cont" := SalesLine."Qty Shipm.Units per Shipm.Cont";
        ItemJnlLine."Packaging Item" := SalesLine."Packaging Item";
        ItemJnlLine."Balance Reg. Customer/Vend.No." := SalesLine.GetBalanceRegCustomerNo;
    end;

    [EventSubscriber(ObjectType::Codeunit, codeunit::"Sales-Post", 'OnPostItemJnlLinePrepareJournalLineOnBeforeCalcQuantities', '', FALSE, FALSE)]
    local procedure OnPostItemJnlLinePrepareJournalLineOnBeforeCalcQuantities(var ItemJnlLine: Record "Item Journal Line"; SalesLine: Record "Sales Line"; QtyToBeShipped: Decimal; QtyToBeShippedBase: Decimal; QtyToBeInvoiced: Decimal; QtyToBeInvoicedBase: Decimal; var IsHandled: Boolean; IsATO: Boolean)
    begin
        IsHandled := True;
        ItemJnlLine.Quantity := -QtyToBeShipped;
        ItemJnlLine."Quantity (Base)" := -QtyToBeShippedBase;
        ItemJnlLine."Invoiced Quantity" := -QtyToBeInvoiced;
        ItemJnlLine."Invoiced Qty. (Base)" := -QtyToBeInvoicedBase;
        IF (ItemJnlLine.Quantity * ItemJnlLine."Quantity Shipment Units" < 0) THEN
            ItemJnlLine."Quantity Shipment Units" := -ItemJnlLine."Quantity Shipment Units";
        IF (ItemJnlLine.Quantity * ItemJnlLine."Quantity Shipment Containers" < 0) THEN
            ItemJnlLine."Quantity Shipment Containers" := -ItemJnlLine."Quantity Shipment Containers";
    end;

    [EventSubscriber(ObjectType::Codeunit, codeunit::"Sales-Post", 'OnPostItemJnlLineOnAfterCopyDocumentFields', '', FALSE, FALSE)]
    local procedure OnPostItemJnlLineOnAfterCopyDocumentFields(var ItemJournalLine: Record "Item Journal Line"; SalesLine: Record "Sales Line"; WarehouseReceiptHeader: Record "Warehouse Receipt Header"; WarehouseShipmentHeader: Record "Warehouse Shipment Header")
    begin
        IF ItemJournalLine."Balance Reg. Customer/Vend.No." <> '' THEN
            ItemJournalLine.GetBalanceRegDirection;
    end;
    //saleinvoice
    [EventSubscriber(ObjectType::Table, database::"Sales Shipment Line", 'OnAfterClearSalesLineValues', '', FALSE, FALSE)]
    local procedure OnAfterClearSalesLineValues(var SalesShipmentLine: Record "Sales Shipment Line"; var SalesLine: Record "Sales Line")
    begin
        SalesLine."Qty. Shipped Shipment Units" := 0;
        SalesLine."Qty. Shipped Shipm. Containers" := 0;
        SalesLine."Qty. to Ship Shipment Units" := 0;
        SalesLine."Qty. to Ship Shipm. Containers" := 0;
    end;

    [EventSubscriber(ObjectType::Table, database::"Sales Shipment Line", 'OnInsertInvLineFromShptLineOnAfterUpdatePrepaymentsAmounts', '', FALSE, FALSE)]
    local procedure OnInsertInvLineFromShptLineOnAfterUpdatePrepaymentsAmounts(var SalesLine: Record "Sales Line"; var SalesOrderLine: Record "Sales Line"; var SalesShipmentLine: Record "Sales Shipment Line")
    begin
        IF SalesLine."Shipment Unit" <> '' THEN
            SalesLine.VALIDATE("Quantity Shipment Units",
              ROUND((SalesShipmentLine.Quantity - SalesShipmentLine."Quantity Invoiced") / SalesLine."Qty. per Shipment Unit", 1, '>'));
        IF SalesLine."Shipment Container" <> '' THEN
            SalesLine.VALIDATE("Quantity Shipment Containers",
              ROUND((SalesShipmentLine.Quantity - SalesShipmentLine."Quantity Invoiced") / SalesLine."Qty. per Shipment Container", 1, '>'));

    end;
    //ajouter lignes commentaire facture 
    [EventSubscriber(ObjectType::Table, database::"Sales Shipment Line", 'OnAfterDescriptionSalesLineInsert', '', FALSE, FALSE)]
    local procedure OnAfterDescriptionSalesLineInsert(var SalesLine: Record "Sales Line"; SalesShipmentLine: Record "Sales Shipment Line"; var NextLineNo: Integer)
    var
        PackagingShipmentText: Boolean;
        SalesShipmentHeader: record "Sales Shipment Header";
    begin
        NextLineNo := NextLineNo + 10000;
        if SalesShipmentHeader.get(SalesShipmentLine."Document No.") then
            IF NOT PackagingShipmentText THEN BEGIN
                SalesLine.INIT;
                SalesLine."Line No." := NextLineNo;
                SalesLine."Document Type" := SalesLine."Document Type";
                SalesLine."Document No." := SalesLine."Document No.";
                SalesLine.Description := STRSUBSTNO(Text002, SalesShipmentHeader."Order No.");
                SalesLine."Sell-to Customer No." := SalesShipmentLine."Sell-to Customer No.";
                SalesLine."Shipment No." := SalesShipmentLine."Document No.";
                SalesLine.INSERT;
            END;
    end;
    // Enleve l'option de validation et laisser que l'expédition
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Sales-Post (Yes/No)", 'OnBeforeConfirmSalesPost', '', FALSE, FALSE)]
    local procedure OnBeforeConfirmSalesPost(var SalesHeader: Record "Sales Header"; var HideDialog: Boolean; var IsHandled: Boolean; var DefaultOption: Integer; var PostAndSend: Boolean)
    var
        lText001: TextConst ENU = 'Do you want to post this order',
                            FRA = 'Voulez-vous valider la commande?';
        lText002: TextConst ENU = 'Operation is cancelled',
                            FRA = 'Opération annulée';
    begin
        if SalesHeader."Document Type" = SalesHeader."Document Type"::Order then begin
            if Not Confirm(StrSubstNo(lText001)) then
                Error(lText002);
            DefaultOption := 1;
            HideDialog := true;
            SalesHeader.Ship := true;
        end;
    end;



    //
    procedure IsPackagingItem(): Boolean
    var
        Packaging: Record "WDC Packaging";
    begin
        Packaging.RESET;
        Packaging.SETCURRENTKEY("Item No.");
        Packaging.SETFILTER("Item No.", item."No.");

        EXIT(NOT Packaging.ISEMPTY);
    end;

    procedure MaxShipUnitsToInvoice(psalesline: Record "Sales Line"): Decimal
    begin
        IF psalesline."Document Type" IN [psalesline."Document Type"::"Return Order", psalesline."Document Type"::"Credit Memo"] THEN
            EXIT(psalesline."Return Qty. Received S.Units" + psalesline."Return Qty. to Receive S.Units" - psalesline."Qty. S.Units Invoiced")
        ELSE
            EXIT(psalesline."Qty. Shipped Shipment Units" + psalesline."Qty. to Ship Shipment Units" - psalesline."Qty. S.Units Invoiced");
    end;

    procedure MaxShipContToInvoice(psalesline: Record "Sales Line"): Decimal
    begin
        IF psalesline."Document Type" IN [psalesline."Document Type"::"Return Order", psalesline."Document Type"::"Credit Memo"] THEN
            EXIT(psalesline."Return Qty. Received S.Cont." + psalesline."Return Qty. to Receive S.Cont." - psalesline."Qty. S.Cont. Invoiced")
        ELSE
            EXIT(psalesline."Qty. Shipped Shipm. Containers" + psalesline."Qty. to Ship Shipm. Containers" - psalesline."Qty. S.Cont. Invoiced");
    end;

    // procedure CalcPackagingQuantityToShip(psalesline: Record "Sales Line")
    // begin
    //     IF (psalesline."Shipment Unit" <> '') THEN BEGIN
    //         IF psalesline."Document Type" IN [psalesline."Document Type"::"Return Order", psalesline."Document Type"::"Credit Memo"] THEN BEGIN
    //             // IF (CurrFieldNo <> FIELDNO( psalesline."Return Qty. to Receive")) AND
    //             //    (NOT OverruleCalcPackagingCheck) THEN
    //             //IF (NOT OverruleCalcPackagingCheck) THEN 
    //             //EXIT;
    //             psalesline."Return Qty. to Receive S.Units" := round(psalesline."Return Qty. to Receive" / psalesline."Qty. per Shipment Unit", 1, '>') -
    //                                                 psalesline."Reserv Qty. to Post Ship.Unit";

    //             IF (psalesline."Return Qty. to Receive S.Units" * psalesline."Quantity Shipment Units" < 0) OR
    //               (ABS(psalesline."Return Qty. to Receive S.Units") > ABS(psalesline."Quantity Shipment Units" - psalesline."Return Qty. Received S.Units")) OR
    //               (psalesline."Quantity Shipment Units" * (psalesline."Quantity Shipment Units" - psalesline."Return Qty. Received S.Units") < 0)
    //             THEN
    //                 psalesline."Return Qty. to Receive S.Units" := psalesline."Quantity Shipment Units" -
    //                   (psalesline."Return Qty. Received S.Units" + psalesline."Reserv Qty. to Post Ship.Unit");
    //         END ELSE BEGIN
    //             // IF (CurrFieldNo <> FIELDNO( psalesline."Qty. to Ship")) AND
    //             //    (NOT OverruleCalcPackagingCheck) THEN
    //             // IF (NOT OverruleCalcPackagingCheck) THEN 
    //             //   EXIT;
    //             psalesline."Qty. to Ship Shipment Units" := round(psalesline."Qty. to Ship" / psalesline."Qty. per Shipment Unit", 1, '>') -
    //                                              psalesline."Reserv Qty. to Post Ship.Unit";
    //             IF (psalesline."Qty. to Ship Shipment Units" * psalesline."Quantity Shipment Units" < 0) OR
    //               (ABS(psalesline."Qty. to Ship Shipment Units") > ABS(psalesline."Quantity Shipment Units" - psalesline."Qty. Shipped Shipment Units")) OR
    //               (psalesline."Quantity Shipment Units" * (psalesline."Quantity Shipment Units" - psalesline."Qty. Shipped Shipment Units") < 0)
    //             THEN
    //                 psalesline."Qty. to Ship Shipment Units" := psalesline."Quantity Shipment Units" -
    //                   (psalesline."Qty. Shipped Shipment Units" + psalesline."Reserv Qty. to Post Ship.Unit");
    //         END;
    //     END;

    //     IF (psalesline."Shipment Container" <> '') THEN BEGIN
    //         IF psalesline."Document Type" IN [psalesline."Document Type"::"Return Order", psalesline."Document Type"::"Credit Memo"] THEN BEGIN
    //             // IF (CurrFieldNo <> FIELDNO(psalesline."Return Qty. to Receive")) AND
    //             //    (NOT OverruleCalcPackagingCheck) THEN
    //             // IF (NOT OverruleCalcPackagingCheck) THEN 
    //             //   EXIT;
    //             psalesline."Return Qty. to Receive S.Cont." := round(psalesline."Return Qty. to Receive" / psalesline."Qty. per Shipment Container", 1, '>') -
    //                                                 psalesline."Reserv Qty. to Post Ship.Cont.";

    //             IF (psalesline."Return Qty. to Receive S.Cont." * psalesline."Quantity Shipment Containers" < 0) OR
    //               (ABS(psalesline."Return Qty. to Receive S.Cont.") > ABS(psalesline."Quantity Shipment Containers" - psalesline."Return Qty. Received S.Cont.")) OR
    //               (psalesline."Quantity Shipment Containers" * (psalesline."Quantity Shipment Containers" - psalesline."Return Qty. Received S.Cont.") < 0)
    //             THEN
    //                 psalesline."Return Qty. to Receive S.Cont." := psalesline."Quantity Shipment Containers" -
    //                   (psalesline."Return Qty. Received S.Cont." + psalesline."Reserv Qty. to Post Ship.Cont.");
    //         END ELSE BEGIN
    //             // IF (CurrFieldNo <> FIELDNO( psalesline."Qty. to Ship")) AND
    //             //    (NOT OverruleCalcPackagingCheck) THEN
    //             // IF (NOT OverruleCalcPackagingCheck) THEN 
    //             //   EXIT;
    //             psalesline."Qty. to Ship Shipm. Containers" := Round(psalesline."Qty. to Ship" / psalesline."Qty. per Shipment Container", 1, '>') -
    //                                                 psalesline."Reserv Qty. to Post Ship.Cont.";
    //             IF (psalesline."Qty. to Ship Shipm. Containers" * psalesline."Quantity Shipment Containers" < 0) OR
    //               (ABS(psalesline."Qty. to Ship Shipm. Containers") > ABS(psalesline."Quantity Shipment Containers" - psalesline."Qty. Shipped Shipm. Containers")) OR
    //               (psalesline."Quantity Shipment Containers" * (psalesline."Quantity Shipment Containers" - psalesline."Qty. Shipped Shipm. Containers") < 0)
    //             THEN
    //                 psalesline."Qty. to Ship Shipm. Containers" := psalesline."Quantity Shipment Containers" -
    //                   (psalesline."Qty. Shipped Shipm. Containers" + psalesline."Reserv Qty. to Post Ship.Cont.");
    //         END;
    //     END;

    // end;
    //validation
    procedure AddOrderPackaging(SalesHeader: Record 36)
    var
        SalesLine: Record 37;
        SalesLine2: Record 37;
        LineNo: Integer;
    begin
        SalesLine.RESET;
        SalesLine.SETRANGE("Document Type", SalesHeader."Document Type");
        SalesLine.SETRANGE("Document No.", SalesHeader."No.");
        SalesLine.SETRANGE(Type, SalesLine.Type::Item);
        IF SalesHeader."Document Type" = SalesHeader."Document Type"::"Return Order" THEN
            SalesLine.SETFILTER("Return Qty. to Receive", '<>%1', 0)
        ELSE
            SalesLine.SETFILTER("Qty. to Ship", '<>%1', 0);

        IF SalesLine.FINDSET(TRUE) THEN BEGIN

            SalesLine2.RESET;
            SalesLine2.SETRANGE("Document Type", SalesHeader."Document Type");
            SalesLine2.SETRANGE("Document No.", SalesHeader."No.");
            IF SalesLine2.FINDLAST THEN
                LineNo := SalesLine2."Line No." + 10000
            ELSE
                LineNo := 10000;
            SalesLine2.SETRANGE(Type, SalesLine2.Type::Item);

            REPEAT
                IF (SalesLine."Shipment No." = '') AND
                   (SalesLine."Return Receipt No." = '')
                THEN BEGIN
                    UpdQtyShippedShipmentContCalc(SalesLine);
                    AddOrderLinePackaging(SalesHeader, SalesLine, SalesLine2, LineNo, TRUE);
                    AddOrderLinePackaging(SalesHeader, SalesLine, SalesLine2, LineNo, FALSE);
                END;
            UNTIL SalesLine.NEXT <= 0;
        END;

    END;

    procedure AddCustomerPackaging(SalesHeader: Record 36)
    var
        SalesLine: Record 37;
        CustomerVendorPackaging: Record "WDC Customer/Vendor Packaging";
        Item: Record 27;
        Packaging: Record "WDC Packaging";
    begin
        SalesLine.RESET;
        SalesLine.SETRANGE("Document Type", SalesHeader."Document Type");
        SalesLine.SETRANGE("Document No.", SalesHeader."No.");
        SalesLine.SETRANGE(Type, SalesLine.Type::Item);
        IF SalesLine.FINDSET THEN
            REPEAT
                IF Item.GET(SalesLine."No.") THEN
                    IF Item.IsPackagingItem THEN BEGIN
                        Packaging.SETCURRENTKEY("Item No.");
                        Packaging.SETRANGE("Item No.", Item."No.");
                        Packaging.FINDFIRST;

                        IF NOT CustomerVendorPackaging.GET(DATABASE::Customer, SalesLine."Sell-to Customer No.", Packaging.Code) THEN BEGIN
                            CustomerVendorPackaging.INIT;
                            CustomerVendorPackaging."Source Type" := DATABASE::Customer;
                            CustomerVendorPackaging."Source No." := SalesLine."Sell-to Customer No.";
                            CustomerVendorPackaging.VALIDATE(Code, Packaging.Code);
                            CustomerVendorPackaging.INSERT(TRUE);
                        END;

                    END;
            UNTIL SalesLine.NEXT <= 0;
    end;

    procedure UpdQtyShippedShipmentContCalc(var SalesLine: Record 37)
    begin
        IF NOT SalesLine."Packaging Item" THEN
            IF SalesLine."Qty Shipm.Units per Shipm.Cont" <> 0 THEN BEGIN
                SalesLine.VALIDATE("Qty. Shipped Shpt. Cont. Calc.",
                                   SalesLine."Qty. Shipped Shpt. Cont. Calc." +
                                   SalesLine."Qty. to Ship Shipment Units" / SalesLine."Qty Shipm.Units per Shipm.Cont");
            END ELSE
                SalesLine.VALIDATE("Qty. Shipped Shpt. Cont. Calc.", SalesLine."Qty. Shipped Shipm. Containers");
    end;

    procedure AddOrderLinePackaging(SalesHeader: Record 36; var SalesLine: Record 37; var SalesLine2: Record 37; var LineNo: Integer; ShipmentUnit: Boolean)
    var
        Packaging: Record "WDC Packaging";
        Item: Record 27;
        Location2: Record 14;
        BinContent: Record 7302;
        CustomerVendorPackaging: Record "WDC Customer/Vendor Packaging";
        SalesHeader2: Record 36;
        ShippingAgent: Record 291;
        ExtraQuantity: Decimal;
        ReturnQtytoReceive: Decimal;
        QtytoShip: Decimal;
        QtytoShipLine: Decimal;
        SalesHeaderNo: Code[20];
        BoundShipment: Boolean;
        lBinCode: Code[20];
    begin
        SalesHeaderNo := SalesHeader."No.";
        IF ShipmentUnit THEN BEGIN
            ReturnQtytoReceive := SalesLine."Return Qty. to Receive S.Units";
            QtytoShip := SalesLine."Qty. to Ship Shipment Units";
        END ELSE BEGIN
            ReturnQtytoReceive := SalesLine."Return Qty. to Receive S.Cont.";
            QtytoShip := SalesLine."Qty. to Ship Shipm. Containers";
        END;

        IF SalesLine."Document Type" IN [SalesLine."Document Type"::"Credit Memo", SalesLine."Document Type"::"Return Order"] THEN BEGIN
            IF ReturnQtytoReceive <> 0 THEN BEGIN
                IF ShipmentUnit THEN BEGIN
                    SalesLine.TESTFIELD("Shipment Unit");
                    Packaging.GET(SalesLine."Shipment Unit");
                END ELSE BEGIN
                    SalesLine.TESTFIELD("Shipment Container");
                    Packaging.GET(SalesLine."Shipment Container");
                END;
                IF Packaging."Register Balance" THEN BEGIN

                    Packaging.TESTFIELD("Item No.");
                    Item.GET(Packaging."Item No.");

                    SalesLine2.SETRANGE("No.", Packaging."Item No.");
                    SalesLine2.SETRANGE("Location Code", SalesLine."Location Code");
                    SalesLine2.SETRANGE("Packaging Return", (ReturnQtytoReceive < 0));
                    SalesLine2.SETRANGE("Return Receipt No.", SalesLine."Return Receipt No.");
                    IF SalesLine2.FINDFIRST THEN BEGIN
                        ExtraQuantity := SalesLine2."Return Qty. to Receive" + ReturnQtytoReceive -
                                        SalesLine2."Outstanding Quantity";
                        QtytoShipLine := SalesLine2."Return Qty. to Receive";
                        IF ExtraQuantity > 0 THEN
                            SalesLine2.VALIDATE(Quantity, SalesLine2.Quantity + ExtraQuantity);
                        SalesLine2.VALIDATE("Return Qty. to Receive", QtytoShipLine +
                                                                    ReturnQtytoReceive);
                        SalesLine2.MODIFY;
                    END ELSE BEGIN
                        SalesLine2.INIT;
                        SalesLine2."Document Type" := SalesHeader."Document Type";
                        SalesLine2."Document No." := SalesHeader."No.";
                        SalesLine2."Line No." := LineNo;
                        LineNo += 10000;
                        SalesLine2.VALIDATE(Type, SalesLine2.Type::Item);
                        SalesLine2.VALIDATE("No.", Packaging."Item No.");
                        lBinCode := SalesLine2."Bin Code"; //WDC01
                        SalesLine2.VALIDATE("Location Code", SalesLine."Location Code");
                        Location2.GET(SalesLine2."Location Code");
                        IF Location2."Packaging ReceiveShip Bin Code" <> '' THEN
                            SalesLine2."Bin Code" := Location2."Packaging ReceiveShip Bin Code";
                        SalesLine2."Packaging Return" := ReturnQtytoReceive < 0;
                        SalesLine2.VALIDATE(Quantity, ReturnQtytoReceive);
                        SalesLine2.VALIDATE("Job No.", SalesLine."Job No.");
                        SalesLine2.VALIDATE("Return Qty. to Receive", ReturnQtytoReceive);
                        //<<WDC01
                        SalesLine2."Bin Code" := lBinCode;
                        //>>WDC01
                        SalesLine2.INSERT;
                    END;
                    IF Location2.GET(SalesLine2."Location Code") THEN
                        IF Location2."Bin Mandatory" AND NOT Location2."Directed Put-away and Pick" THEN
                            IF SalesLine2."Bin Code" = '' THEN
                                ERROR(Text001, BinContent.FIELDCAPTION(Default), BinContent.TABLECAPTION,
                                                SalesLine2.FIELDCAPTION("No."), SalesLine2."No.");
                END;

                IF ShipmentUnit THEN BEGIN
                    SalesLine."Reserv Qty. to Post Ship.Unit" := ReturnQtytoReceive;
                    SalesLine."Return Qty. to Receive S.Units" := 0;
                END ELSE BEGIN
                    SalesLine."Reserv Qty. to Post Ship.Cont." := ReturnQtytoReceive;
                    SalesLine."Return Qty. to Receive S.Cont." := 0;
                END;
                SalesLine.MODIFY;
            END;
        END;


        IF ShipmentUnit THEN BEGIN
            SalesLine."Reserv Qty. to Post Ship.Unit" := QtytoShip;
            SalesLine."Qty. to Ship Shipment Units" := 0;
        END ELSE BEGIN
            SalesLine."Reserv Qty. to Post Ship.Cont." := QtytoShip;
            SalesLine."Qty. to Ship Shipm. Containers" := 0;
        END;
        SalesLine.MODIFY;
    END;


    var
        Item: Record 27;
        SalesSetup: record 311;
        Text001: TextConst ENU = '%1 %2 does not exist for %3 %4.', FRA = '%1 %2 n''existe pas pour %3 %4.';
        Text002: TextConst ENU = 'Sales Order No.: %1', FRA = 'N° commande de vente : %1';



}
