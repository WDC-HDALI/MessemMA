codeunit 50001 "WDC Subscriber Purchase"
{
    [EventSubscriber(ObjectType::Table, database::"Purchase Line", 'OnAfterValidateNopurchaseline', '', FALSE, FALSE)]
    procedure OnAfterValidateNo(var PurchaseLine: Record "Purchase Line"; var xPurchaseLine: Record "Purchase Line"; var TempPurchaseLine: Record "Purchase Line" temporary)
    begin
        item.reset();
        if item.get(PurchaseLine."No.") then
            PurchaseLine."Packaging Item" := IsPackagingItem();
        IF NOT PurchaseLine."Packaging Item" THEN BEGIN
            PurchaseLine."Shipment Unit" := Item."Shipment Unit";
            PurchaseLine."Shipment Container" := Item."Shipment Container";
        END ELSE BEGIN
            PurchaseLine."Shipment Unit" := '';
            PurchaseLine."Shipment Container" := '';
        END;
        IF ((PurchaseLine."Shipment Unit" <> '') And (PurchaseLine."Qty. per Unit of Measure" <> 0)) THEN
            PurchaseLine."Qty. per Shipment Unit" := Item."Qty. per Shipment Unit" / PurchaseLine."Qty. per Unit of Measure"
        ELSE
            PurchaseLine."Qty. per Shipment Unit" := 1;
        IF ((PurchaseLine."Shipment Container" <> '') and (PurchaseLine."Qty. per Unit of Measure" <> 0)) THEN
            PurchaseLine."Qty. per Shipment Container" := Item."Qty. per Shipment Container" / PurchaseLine."Qty. per Unit of Measure"
        ELSE
            PurchaseLine."Qty. per Shipment Container" := 1;
        IF Item."Shipm.Units per Shipm.Containr" <> 0 THEN
            PurchaseLine."Qty Shipm.Units per Shipm.Cont" := Item."Shipm.Units per Shipm.Containr"
        ELSE
            PurchaseLine."Qty Shipm.Units per Shipm.Cont" := 1;

    end;

    [EventSubscriber(ObjectType::Table, database::"Purchase Line", 'OnAfterInitQtyToReceive', '', FALSE, FALSE)]
    local procedure OnAfterInitQtyToReceive(var PurchLine: Record "Purchase Line"; CurrFieldNo: Integer)

    begin
        IF (PurchLine."Outstanding Quantity" <> 0) THEN begin
            IF PurchLine."Shipment Unit" <> '' THEN BEGIN
                PurchLine."Qty. to Receive Shipment Units" := PurchLine."Quantity Shipment Units" - PurchLine."Qty. Received Shipment Units";
                PurchLine."Qty. S.Units to invoice" := PurchLine.MaxShipUnitsToInvoice;

            END;
            IF PurchLine."Shipment Container" <> '' then BEGIN
                PurchLine."Qty. to Rec. Shipm. Containers" := PurchLine."Quantity Shipment Containers" -
             (PurchLine."Qty. Received Shipm.Containers" + PurchLine."Reserv Qty. to Post Ship.Cont.");
                PurchLine."Qty. S.Cont. to invoice" := PurchLine.MaxShipContToInvoice;

            END;
        end;
    end;
    //correction flux : reception partielle 
    [EventSubscriber(ObjectType::Table, database::"Purchase Line", 'OnValidateQtyToReceiveOnAfterCheckQty', '', FALSE, FALSE)]
    local procedure OnValidateQtyToReceiveOnAfterCheckQty(var PurchaseLine: Record "Purchase Line"; CurrFieldNo: Integer)
    begin
        PurchaseLine.CalcPackagingQuantityToReceive();
    end;

    [EventSubscriber(ObjectType::Table, database::"Purchase Line", 'OnValidateReturnQtyToShipOnAfterInitQty', '', FALSE, FALSE)]
    local procedure OnValidateReturnQtyToShipOnAfterInitQty(var PurchaseLine: Record "Purchase Line"; var xPurchaseLine: Record "Purchase Line"; CurrentFieldNo: Integer; var IsHandled: Boolean)
    begin
        PurchaseLine.CalcPackagingQuantityToReceive();
    end;
    //

    [EventSubscriber(ObjectType::Table, database::"Purchase Line", 'OnAfterInitQtyToShip', '', FALSE, FALSE)]
    local procedure OnAfterInitQtyToShip(var PurchLine: Record "Purchase Line"; CurrFieldNo: Integer)
    begin
        PurchSetup.Get();
        IF (PurchSetup."Default Qty. to Receive" = PurchSetup."Default Qty. to Receive"::Remainder) OR
           (PurchLine."Document Type" = PurchLine."Document Type"::"Credit Memo") then begin
            IF (PurchLine."Outstanding Quantity" <> 0) THEN begin
                PurchLine."Return Qty. to Ship S.Units" := PurchLine."Quantity Shipment Units" -
                (PurchLine."Return Qty. Shipped S.Units" + PurchLine."Reserv Qty. to Post Ship.Unit");
                PurchLine."Return Qty. to Ship S.Cont." := PurchLine."Quantity Shipment Containers" -
                    (PurchLine."Return Qty. Shipped S.Cont." + PurchLine."Reserv Qty. to Post Ship.Cont.");
            end;
        end;
    end;

    [EventSubscriber(ObjectType::Table, database::"Purchase Line", 'OnAfterInitQtyToInvoice', '', FALSE, FALSE)]
    local procedure OnAfterInitQtyToInvoice(var PurchLine: Record "Purchase Line"; CurrFieldNo: Integer)
    begin
        PurchLine."Qty. S.Units to invoice" := PurchLine.MaxShipUnitsToInvoice;
        PurchLine."Qty. S.Cont. to invoice" := PurchLine.MaxShipContToInvoice;

    end;

    [EventSubscriber(ObjectType::Codeunit, codeunit::"Purch.-Post", 'OnRunOnAfterFillTempLines', '', FALSE, FALSE)]
    local procedure OnRunOnAfterFillTempLines(var PurchHeader: Record "Purchase Header")
    begin
        IF PurchHeader."Document Type" IN [PurchHeader."Document Type"::Order, PurchHeader."Document Type"::"Return Order", PurchHeader."Document Type"::Invoice, PurchHeader."Document Type"::"Credit Memo"] THEN
            AddOrderPackaging(PurchHeader);
        IF PurchHeader."Document Type" IN [PurchHeader."Document Type"::Order, PurchHeader."Document Type"::"Credit Memo"] THEN
            AddVendorPackaging(PurchHeader);
    end;

    [EventSubscriber(ObjectType::Table, database::"item journal line", 'OnValidateItemNoOnAfterCalcUnitCost', '', FALSE, FALSE)]
    local procedure OnValidateItemNoOnAfterCalcUnitCost(var ItemJournalLine: Record "Item Journal Line"; Item: Record Item)
    begin
        ItemJournalLine."Packaging Item" := IsPackagingItem();
        ItemJournalLine."Shipment Unit" := item."Shipment Unit";
        IF Item."Shipm.Units per Shipm.Containr" <> 0 THEN
            ItemJournalLine."Qty Shipm.Units per Shipm.Cont" := Item."Shipm.Units per Shipm.Containr"
        ELSE
            ItemJournalLine."Qty Shipm.Units per Shipm.Cont" := 1;
    end;

    [EventSubscriber(ObjectType::Table, database::"item journal line", 'OnValidateItemNoOnAfterGetItem', '', FALSE, FALSE)]
    local procedure OnValidateItemNoOnAfterGetItem(var ItemJournalLine: Record "Item Journal Line"; Item: Record Item)
    begin
        ItemJournalLine.GetBalanceRegistration();
    end;

    [EventSubscriber(ObjectType::Table, database::"item journal line", 'OnValidateQuantityOnBeforeGetUnitAmount', '', FALSE, FALSE)]
    local procedure OnValidateQuantityOnBeforeGetUnitAmount(var ItemJournalLine: Record "Item Journal Line"; xItemJournalLine: Record "Item Journal Line"; CallingFieldNo: Integer)
    begin
        IF NOT (ItemJournalLine."Entry Type" IN [ItemJournalLine."Entry Type"::Purchase, ItemJournalLine."Entry Type"::Sale]) THEN BEGIN
            IF (ItemJournalLine."Shipment Unit" <> '') THEN
                ItemJournalLine."Quantity Shipment Units" := ROUND(ItemJournalLine."Quantity (Base)" / Item."Qty. per Shipment Unit", 1, '>');
            IF (ItemJournalLine."Shipment Container" <> '') THEN
                ItemJournalLine."Quantity Shipment Containers" := ROUND(ItemJournalLine."Quantity (Base)" / Item."Qty. per Shipment Container", 1, '>')
        END;
    end;

    [EventSubscriber(ObjectType::Table, database::"item journal line", 'OnAfterCopyItemJnlLineFromPurchLine', '', FALSE, FALSE)]
    local procedure OnAfterCopyItemJnlLineFromPurchLine(var ItemJnlLine: Record "Item Journal Line"; PurchLine: Record "Purchase Line")
    begin
        ItemJnlLine."Packaging Item" := PurchLine."Packaging Item";
        ItemJnlLine."Shipment Unit" := PurchLine."Shipment Unit";
        ItemJnlLine."Shipment Container" := PurchLine."Shipment Container";
        ItemJnlLine."Quantity Shipment Units" := PurchLine."Reserv Qty. to Post Ship.Unit";
        ItemJnlLine."Quantity Shipment Containers" := PurchLine."Reserv Qty. to Post Ship.Cont.";
        ItemJnlLine."Qty Shipm.Units per Shipm.Cont" := PurchLine."Qty Shipm.Units per Shipm.Cont";
        ItemJnlLine."Balance Reg. Customer/Vend.No." := PurchLine.GetBalanceRegVendorNo();
        ItemJnlLine."Purchase Order No." := PurchLine."Document No.";
    end;

    [EventSubscriber(ObjectType::Codeunit, codeunit::"Purch.-Post", 'OnPostItemJnlLineOnBeforeInitAmount', '', FALSE, FALSE)]
    local procedure OnPostItemJnlLineOnBeforeInitAmount(var ItemJnlLine: Record "Item Journal Line"; PurchHeader: Record "Purchase Header"; var PurchLine: Record "Purchase Line")
    begin
        IF ItemJnlLine."Balance Reg. Customer/Vend.No." <> '' THEN
            ItemJnlLine.GetBalanceRegDirection;
    end;



    [EventSubscriber(ObjectType::Codeunit, codeunit::"Item Jnl.-Post Line", 'OnAfterInitItemLedgEntry', '', FALSE, FALSE)]
    local procedure OnAfterInitItemLedgEntry(var NewItemLedgEntry: Record "Item Ledger Entry"; var ItemJournalLine: Record "Item Journal Line"; var ItemLedgEntryNo: Integer)
    begin
        NewItemLedgEntry."Packaging Item" := ItemJournalLine."Packaging Item";
        NewItemLedgEntry."Shipment Unit" := ItemJournalLine."Shipment Unit";
        NewItemLedgEntry."Shipment Container" := ItemJournalLine."Shipment Container";
        NewItemLedgEntry."Qty Shipm.Units per Shipm.Cont" := ItemJournalLine."Qty Shipm.Units per Shipm.Cont";
        NewItemLedgEntry."Balance Reg. Customer/Vend.No." := ItemJournalLine."Balance Reg. Customer/Vend.No.";
        NewItemLedgEntry."Balance Registration Direction" := ItemJournalLine."Balance Registration Direction";
        NewItemLedgEntry."Purchase Order No." := ItemJournalLine."Purchase Order No.";
        IF ItemJournalLine."Entry Type" IN
            [ItemJournalLine."Entry Type"::Sale,
             ItemJournalLine."Entry Type"::"Negative Adjmt.",
             ItemJournalLine."Entry Type"::Transfer,
             ItemJournalLine."Entry Type"::Consumption,
             ItemJournalLine."Entry Type"::"Assembly Consumption"]
       THEN BEGIN
            NewItemLedgEntry."Quantity Shipment Units" := -ItemJournalLine."Quantity Shipment Units";
            NewItemLedgEntry."Quantity Shipment Containers" := -ItemJournalLine."Quantity Shipment Containers";

        END
        ELSE begin
            NewItemLedgEntry."Quantity Shipment Units" := ItemJournalLine."Quantity Shipment Units";
            NewItemLedgEntry."Quantity Shipment Containers" := ItemJournalLine."Quantity Shipment Containers";

        end;
    end;

    [EventSubscriber(ObjectType::Table, database::"Return Shipment Line", 'OnAfterInitFromPurchLine', '', FALSE, FALSE)]
    local procedure OnAfterInitFromPurchLine(ReturnShptHeader: Record "Return Shipment Header"; PurchLine: Record "Purchase Line"; var ReturnShptLine: Record "Return Shipment Line")
    begin
        ReturnShptLine."Quantity Shipment Units" := PurchLine."Reserv Qty. to Post Ship.Unit";
        ReturnShptLine."Quantity Shipment Containers" := PurchLine."Reserv Qty. to Post Ship.Cont.";
    end;
    //invoice
    [EventSubscriber(ObjectType::Table, database::"Purch. Rcpt. Line", 'OnAfterCopyFromPurchRcptLine', '', FALSE, FALSE)]
    local procedure OnAfterCopyFromPurchRcptLine(var PurchaseLine: Record "Purchase Line"; PurchRcptLine: Record "Purch. Rcpt. Line"; var TempPurchLine: Record "Purchase Line")
    begin
        PurchaseLine."Qty. Received Shipment Units" := 0;
        PurchaseLine."Qty. Received Shipm.Containers" := 0;
        PurchaseLine."Qty. to Receive Shipment Units" := 0;
        PurchaseLine."Qty. to Rec. Shipm. Containers" := 0;
    end;

    [EventSubscriber(ObjectType::Table, database::"Purch. Rcpt. Line", OnInsertInvLineFromRcptLineOnBeforeValidateQuantity, '', FALSE, FALSE)]
    local procedure OnInsertInvLineFromRcptLineOnBeforeValidateQuantity(PurchRcptLine: Record "Purch. Rcpt. Line"; var PurchaseLine: Record "Purchase Line"; var IsHandled: Boolean; var PurchInvHeader: Record "Purchase Header")
    begin
        PurchaseLine.VALIDATE(Quantity, PurchRcptLine.Quantity - PurchRcptLine."Quantity Invoiced");
        IF PurchaseLine."Shipment Unit" <> '' THEN
            PurchaseLine.VALIDATE("Quantity Shipment Units",
              ROUND((PurchRcptLine.Quantity - PurchRcptLine."Quantity Invoiced") / PurchaseLine."Qty. per Shipment Unit", 1, '>'));
        IF PurchaseLine."Shipment Container" <> '' THEN
            PurchaseLine.VALIDATE("Quantity Shipment Containers",
              ROUND((PurchRcptLine.Quantity - PurchRcptLine."Quantity Invoiced") / PurchaseLine."Qty. per Shipment Container", 1, '>'));
    end;

    [EventSubscriber(ObjectType::Table, database::"Purch. Inv. Line", 'OnAfterInitFromPurchLine', '', FALSE, FALSE)]
    local procedure OnAfterInitFromPurchLine2(PurchInvHeader: Record "Purch. Inv. Header"; PurchLine: Record "Purchase Line"; var PurchInvLine: Record "Purch. Inv. Line")
    begin
        PurchInvLine."Quantity Shipment Units" := PurchLine."Qty. S.Units to invoice";
        PurchInvLine."Quantity Shipment Containers" := PurchLine."Qty. S.Cont. to invoice";
    end;

    [EventSubscriber(ObjectType::Codeunit, codeunit::"Purch.-Post", 'OnAfterUpdatePurchLineBeforePost', '', FALSE, FALSE)]
    local procedure OnAfterUpdatePurchLineBeforePost(var PurchaseLine: Record "Purchase Line"; WhseShip: Boolean; WhseReceive: Boolean; PurchaseHeader: Record "Purchase Header"; RoundingLineInserted: Boolean)
    begin
        IF (PurchaseHeader."Document Type" = PurchaseHeader."Document Type"::Invoice) AND (PurchaseLine."Receipt No." <> '') THEN BEGIN
            PurchaseLine."Qty. Received Shipment Units" := PurchaseLine."Quantity Shipment Units";
            PurchaseLine."Qty. Received Shipm.Containers" := PurchaseLine."Quantity Shipment Containers";
            PurchaseLine."Reserv Qty. to Post Ship.Unit" := 0;
            PurchaseLine."Reserv Qty. to Post Ship.Cont." := 0;
        end;
        IF (PurchaseHeader."Document Type" = PurchaseHeader."Document Type"::"Credit Memo") AND (PurchaseLine."Return Shipment No." <> '') THEN BEGIN
            PurchaseLine."Return Qty. Shipped S.Units" := PurchaseLine."Quantity Shipment Units";
            PurchaseLine."Return Qty. Shipped S.Cont." := PurchaseLine."Quantity Shipment Containers";
            PurchaseLine."Reserv Qty. to Post Ship.Unit" := 0;
            PurchaseLine."Reserv Qty. to Post Ship.Cont." := 0;
        end;
    end;
    //corection facture 
    [EventSubscriber(ObjectType::Codeunit, codeunit::"Purch.-Post", 'OnBeforeUpdateQtyToInvoiceForOrder', '', FALSE, FALSE)]
    local procedure OnBeforeUpdateQtyToInvoiceForOrder(var PurchHeader: Record "Purchase Header"; TempPurchLine: Record "Purchase Line" temporary; var IsHandled: Boolean)
    begin
        if Abs(TempPurchLine."Quantity Invoiced" + TempPurchLine."Qty. to Invoice") > Abs(TempPurchLine."Quantity Received") then begin
            TempPurchLine.VALIDATE(TempPurchLine."Qty. S.Units to invoice",
                   TempPurchLine."Qty. Received Shipment Units" - TempPurchLine."Qty. S.Units Invoiced");
            TempPurchLine.VALIDATE(TempPurchLine."Qty. S.Cont. to invoice",
              TempPurchLine."Qty. Received Shipm.Containers" - TempPurchLine."Qty. S.Cont. Invoiced");
        end;
    end;

    [EventSubscriber(ObjectType::Codeunit, codeunit::"Purch.-Post", 'OnPostUpdateOrderLineOnSetDefaultQtyBlank', '', FALSE, FALSE)]
    local procedure OnPostUpdateOrderLineOnSetDefaultQtyBlank(var PurchaseHeader: Record "Purchase Header"; var TempPurchaseLine: Record "Purchase Line" temporary; PurchPost: Record "Purchases & Payables Setup"; var SetDefaultQtyBlank: Boolean)
    begin
        TempPurchaseLine."Reserv Qty. to Post Ship.Unit" := 0;
        TempPurchaseLine."Reserv Qty. to Post Ship.Cont." := 0;

    end;

    local procedure OnBeforeUpdateQtyToInvoiceForReturnOrder(var PurchHeader: Record "Purchase Header"; TempPurchLine: Record "Purchase Line" temporary; var IsHandled: Boolean)
    begin
        if Abs(TempPurchLine."Quantity Invoiced" + TempPurchLine."Qty. to Invoice") > Abs(TempPurchLine."Return Qty. Shipped") then begin
            TempPurchLine.VALIDATE(TempPurchLine."Qty. S.Units to invoice",
                TempPurchLine."Return Qty. Shipped S.Units" - TempPurchLine."Qty. S.Units Invoiced");
            TempPurchLine.VALIDATE(TempPurchLine."Qty. S.Cont. to invoice",
              TempPurchLine."Return Qty. Shipped S.Cont." - TempPurchLine."Qty. S.Cont. Invoiced");
        end;
        TempPurchLine."Qty. S.Units Invoiced" := TempPurchLine."Qty. S.Units Invoiced" + TempPurchLine."Qty. S.Units to invoice";
        TempPurchLine."Qty. S.Cont. Invoiced" := TempPurchLine."Qty. S.Cont. Invoiced" + TempPurchLine."Qty. S.Cont. to invoice";

    end;
    //
    //avoir
    [EventSubscriber(ObjectType::Table, database::"Purch. Cr. Memo Line", 'OnAfterInitFromPurchLine', '', FALSE, FALSE)]
    local procedure OnAfterInitFromPurchLineavoir(PurchCrMemoHdr: Record "Purch. Cr. Memo Hdr."; PurchLine: Record "Purchase Line"; var PurchCrMemoLine: Record "Purch. Cr. Memo Line")
    begin
        PurchCrMemoLine."Quantity Shipment Units" := PurchLine."Qty. S.Units to invoice";
        PurchCrMemoLine."Quantity Shipment Containers" := PurchLine."Qty. S.Cont. to invoice";
        PurchCrMemoLine."Return Shipment No." := PurchLine."Return Shipment No.";
        PurchCrMemoLine."Return Shipment Line No." := PurchLine."Return Shipment Line No.";
    end;
    //filtrage de liste retour
    [EventSubscriber(ObjectType::page, page::"Get Post.Doc - P.RcptLn Sbfrm", 'OnBeforeIsShowRec', '', FALSE, FALSE)]
    local procedure OnBeforeIsShowRec(PurchRcptLine: Record "Purch. Rcpt. Line"; var RevQtyFilter: Boolean; var Result: Boolean; var IsHandled: Boolean; var RemainingQty: Decimal; var RevUnitCostLCY: Decimal; FillExactCostReverse: Boolean)
    begin
        if PurchRcptLine."Packaging Item" = true then
            IsHandled := true;
        //Result := false;
    end;

    // Enleve l'option de validation et laisser que la réception
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Purch.-Post (Yes/No)", 'OnBeforeConfirmPost', '', FALSE, FALSE)]
    local procedure OnBeforeConfirmPost(var PurchaseHeader: Record "Purchase Header"; var HideDialog: Boolean; var IsHandled: Boolean; var DefaultOption: Integer)
    Var

        lText001: TextConst ENU = 'Do you want to post this order',
                            FRA = 'Voulez-vous valider la commande?';
        lText002: TextConst ENU = 'Operation is cancelled',
                            FRA = 'Opération annulée';
    begin
        if PurchaseHeader."Document Type" = PurchaseHeader."Document Type"::Order then begin
            if Not Confirm(StrSubstNo(lText001)) then
                Error(lText002);
            DefaultOption := 1;
            HideDialog := true;
            PurchaseHeader.Receive := true;
        end;
    end;

    procedure AddOrderPackaging(PurchHeader: Record "Purchase Header")
    var
        purchLine: Record "Purchase Line";
        PurchLine2: Record "Purchase Line";
        LineNo: Integer;
    begin

        PurchLine.RESET;
        PurchLine.SETRANGE("Document Type", PurchHeader."Document Type");
        PurchLine.SETRANGE("Document No.", PurchHeader."No.");
        PurchLine.SETRANGE(Type, PurchLine.Type::Item);
        IF PurchHeader."Document Type" = PurchHeader."Document Type"::"Return Order" THEN
            PurchLine.SETFILTER("Return Qty. to Ship", '<>%1', 0)
        ELSE
            PurchLine.SETFILTER("Qty. to Receive", '<>%1', 0);

        IF PurchLine.FINDSET THEN BEGIN

            PurchLine2.RESET;
            PurchLine2.SETRANGE("Document Type", PurchHeader."Document Type");
            PurchLine2.SETRANGE("Document No.", PurchHeader."No.");
            IF PurchLine2.FINDLAST THEN
                LineNo := PurchLine2."Line No." + 10000
            ELSE
                LineNo := 10000;
            PurchLine2.SETRANGE(Type, PurchLine2.Type::Item);

            REPEAT
                IF ((PurchLine."Receipt No." = '') AND
                   (PurchLine."Return Shipment No." = ''))
                THEN BEGIN
                    UpdQtyShippedShipmentContCalc(PurchLine);
                    AddOrderLinePackaging(PurchHeader, PurchLine, PurchLine2, LineNo, true);
                    AddOrderLinePackaging(PurchHeader, PurchLine, PurchLine2, LineNo, false);
                end;
            UNTIL PurchLine.NEXT <= 0;
        end;
    end;

    procedure AddVendorPackaging(PurchHeader: Record 38)
    var
        CustomerVendorPackaging: Record "WDC Customer/Vendor Packaging";
        Item: Record Item;
        PurchLine: Record "Purchase Line";
        Packaging: Record "WDC Packaging";
    begin
        PurchLine.RESET;
        PurchLine.SETRANGE("Document Type", PurchHeader."Document Type");
        PurchLine.SETRANGE("Document No.", PurchHeader."No.");
        PurchLine.SETRANGE(Type, PurchLine.Type::Item);
        IF PurchLine.FINDSET THEN
            REPEAT
                IF Item.GET(PurchLine."No.") THEN
                    IF Item.IsPackagingItem THEN BEGIN
                        Packaging.SETCURRENTKEY("Item No.");
                        Packaging.SETRANGE("Item No.", Item."No.");
                        Packaging.FINDFIRST;
                        IF NOT CustomerVendorPackaging.GET(DATABASE::Vendor, PurchLine."Buy-from Vendor No.", Packaging.Code) THEN BEGIN
                            CustomerVendorPackaging.INIT;
                            CustomerVendorPackaging."Source Type" := DATABASE::Vendor;
                            CustomerVendorPackaging."Source No." := PurchLine."Buy-from Vendor No.";
                            CustomerVendorPackaging.VALIDATE(Code, Packaging.Code);
                            CustomerVendorPackaging.INSERT(TRUE);
                        END;
                    END;
            UNTIL PurchLine.NEXT <= 0;
    end;


    procedure IsPackagingItem(): Boolean
    var
        Packaging: Record "WDC Packaging";
    begin
        Packaging.RESET;
        Packaging.SETCURRENTKEY("Item No.");
        Packaging.SETFILTER("Item No.", item."No.");
        EXIT(NOT Packaging.ISEMPTY);
    end;

    procedure UpdQtyShippedShipmentContCalc(VAR PurchLine: Record "Purchase Line")
    begin
        IF NOT PurchLine."Packaging Item" THEN
            IF PurchLine."Qty Shipm.Units per Shipm.Cont" <> 0 THEN BEGIN
                PurchLine.VALIDATE("Qty. Rec. Shpt. Cont. Calc", PurchLine."Qty. Rec. Shpt. Cont. Calc" +
                                   PurchLine."Qty. to Receive Shipment Units" / PurchLine."Qty Shipm.Units per Shipm.Cont");
            END ELSE
                PurchLine.VALIDATE("Qty. Rec. Shpt. Cont. Calc", PurchLine."Qty. Received Shipm.Containers");
    end;

    procedure AddOrderLinePackaging(PurchHeader: Record "Purchase Header"; VAR PurchLine: Record "Purchase Line"; VAR PurchLine2: Record "Purchase Line"; VAR LineNo: Integer; ShipmentUnit: Boolean)
    var
        ReturnQtytoShip: Decimal;
        QtytoReceive: decimal;
        packaging: Record "WDC Packaging";
        item: Record item;
        ExtraQuantity: decimal;
        QtytoReceiveLine: Decimal;
        Location2: record Location;

    begin
        IF ShipmentUnit THEN BEGIN
            ReturnQtytoShip := PurchLine."Return Qty. to Ship S.Units";
            QtytoReceive := PurchLine."Qty. to Receive Shipment Units";
        END ELSE BEGIN
            ReturnQtytoShip := PurchLine."Return Qty. to Ship S.Cont.";
            QtytoReceive := PurchLine."Qty. to Rec. Shipm. Containers";
        END;
        IF NOT (PurchLine."Document Type" IN [PurchLine."Document Type"::"Credit Memo", PurchLine."Document Type"::"Return Order"]) THEN BEGIN
            IF QtytoReceive <> 0 THEN BEGIN
                if ShipmentUnit THEN BEGIN
                    PurchLine.TESTFIELD("Shipment Unit");
                    Packaging.GET(PurchLine."Shipment Unit");
                END ELSE BEGIN
                    PurchLine.TESTFIELD("Shipment Container");
                    Packaging.GET(PurchLine."Shipment Container");
                END;
                IF Packaging."Register Balance" THEN BEGIN
                    Packaging.TESTFIELD("Item No.");
                    Item.GET(Packaging."Item No.");
                    PurchLine2.SETRANGE("No.", Packaging."Item No.");
                    PurchLine2.SETRANGE("Location Code", PurchLine."Location Code");
                    PurchLine2.SETRANGE("Packaging Return", (QtytoReceive < 0));
                    PurchLine2.SETRANGE("Receipt No.", PurchLine."Receipt No.");
                    IF PurchLine2.FINDFIRST THEN BEGIN
                        ExtraQuantity := PurchLine2."Qty. to Receive" + QtytoReceive - PurchLine2."Outstanding Quantity";
                        IF Location2.GET(PurchLine2."Location Code") THEN
                            IF Location2."Require Receive" THEN BEGIN
                                QtytoReceiveLine := PurchLine2."Qty. to Receive";
                                IF (ExtraQuantity * PurchLine2.Quantity) > 0 THEN
                                    PurchLine2.VALIDATE(Quantity, PurchLine2.Quantity + ExtraQuantity);
                                PurchLine2.VALIDATE("Qty. to Receive", QtytoReceiveLine + QtytoReceive);

                            END ELSE BEGIN
                                QtytoReceiveLine := PurchLine2."Qty. to Receive";
                                IF (ExtraQuantity * PurchLine2.Quantity) > 0 THEN
                                    PurchLine2.VALIDATE(Quantity, PurchLine2.Quantity + ExtraQuantity)
                                ELSE
                                    purchLine2.VALIDATE("Qty. to Receive", QtytoReceiveLine + QtytoReceive);
                            END;
                        PurchLine2.MODIFY;
                    END ELSE BEGIN
                        PurchLine2.INIT;
                        PurchLine2."Document Type" := PurchHeader."Document Type";
                        PurchLine2."Document No." := PurchHeader."No.";
                        PurchLine2."Line No." := LineNo;
                        LineNo += 10000;
                        PurchLine2.VALIDATE(Type, PurchLine2.Type::Item);
                        PurchLine2.VALIDATE("No.", Packaging."Item No.");
                        PurchLine2.VALIDATE("Location Code", PurchLine."Location Code");
                        IF Location2.GET(PurchLine2."Location Code") THEN
                            IF Location2."Packaging ReceiveShip Bin Code" <> '' THEN
                                PurchLine2."Bin Code" := Location2."Packaging ReceiveShip Bin Code";
                        PurchLine2."Packaging Return" := QtytoReceive < 0;
                        PurchLine2.VALIDATE(Quantity, QtytoReceive);
                        PurchLine2.VALIDATE("Job No.", PurchLine."Job No.");
                        PurchLine2.VALIDATE("Qty. to Receive", QtytoReceive);
                        PurchLine2.INSERT;
                    END;
                END;
                IF ShipmentUnit THEN BEGIN
                    PurchLine."Reserv Qty. to Post Ship.Unit" := PurchLine."Reserv Qty. to Post Ship.Unit" + QtytoReceive;
                    PurchLine."Qty. to Receive Shipment Units" := 0;
                END ELSE BEGIN
                    PurchLine."Reserv Qty. to Post Ship.Cont." := PurchLine."Reserv Qty. to Post Ship.Cont." + QtytoReceive;
                    PurchLine."Qty. to Rec. Shipm. Containers" := 0;
                END;
                PurchLine.MODIFY;
            END;
        END ELSE BEGIN
            IF ReturnQtytoShip <> 0 THEN BEGIN
                IF ShipmentUnit THEN BEGIN
                    PurchLine.TESTFIELD("Shipment Unit");
                    Packaging.GET(PurchLine."Shipment Unit");
                END ELSE BEGIN
                    PurchLine.TESTFIELD("Shipment Container");
                    Packaging.GET(PurchLine."Shipment Container");
                END;
                IF Packaging."Register Balance" THEN BEGIN
                    Packaging.TESTFIELD("Item No.");
                    Item.GET(Packaging."Item No.");
                    PurchLine2.SETRANGE("No.", Packaging."Item No.");
                    PurchLine2.SETRANGE("Location Code", PurchLine."Location Code");
                    PurchLine2.SETRANGE("Packaging Return", (ReturnQtytoShip < 0));
                    PurchLine2.SETRANGE("Return Shipment No.", PurchLine."Return Shipment No.");
                    IF PurchLine2.FINDFIRST THEN BEGIN
                        ExtraQuantity := PurchLine2."Return Qty. to Ship" + ReturnQtytoShip -
                                         PurchLine2."Outstanding Quantity";
                        QtytoReceiveLine := PurchLine2."Return Qty. to Ship";
                        IF ExtraQuantity > 0 THEN begin
                            PurchLine2.VALIDATE(Quantity, PurchLine2.Quantity + ExtraQuantity);
                            PurchLine2.VALIDATE("Return Qty. to Ship", QtytoReceiveLine + ReturnQtytoShip);
                            PurchLine2.MODIFY;
                        end;
                    END ELSE BEGIN
                        PurchLine2.INIT;
                        PurchLine2."Document Type" := PurchHeader."Document Type";
                        PurchLine2."Document No." := PurchHeader."No.";
                        PurchLine2."Line No." := LineNo;
                        LineNo += 10000;
                        PurchLine2.VALIDATE(Type, PurchLine2.Type::Item);
                        PurchLine2.VALIDATE("No.", Packaging."Item No.");
                        PurchLine2.VALIDATE("Location Code", PurchLine."Location Code");
                        IF Location2.GET(PurchLine2."Location Code") then
                            IF Location2."Packaging ReceiveShip Bin Code" <> '' THEN
                                PurchLine2."Bin Code" := Location2."Packaging ReceiveShip Bin Code";
                        PurchLine2."Packaging Return" := ReturnQtytoShip < 0;
                        PurchLine2.VALIDATE(Quantity, ReturnQtytoShip);
                        PurchLine2.VALIDATE("Job No.", PurchLine."Job No.");
                        PurchLine2.VALIDATE("Return Qty. to Ship", ReturnQtytoShip);
                        PurchLine2.INSERT;
                    END;
                    //   IF Location2.GET(PurchLine2."Location Code") THEN
                    //     IF Location2."Bin Mandatory" AND
                    //        NOT Location2."Directed Put-away and Pick"
                    //     THEN
                    //       IF PurchLine2."Bin Code" = '' THEN
                    //         ERROR(TextSI017, BinContent.FIELDCAPTION(Default), BinContent.TABLECAPTION,
                    //                          PurchLine2.FIELDCAPTION("No."), PurchLine2."No.");

                    // END;

                    IF ShipmentUnit THEN BEGIN
                        PurchLine."Reserv Qty. to Post Ship.Unit" := PurchLine."Reserv Qty. to Post Ship.Unit" + ReturnQtytoShip;
                        PurchLine."Return Qty. to Ship S.Units" := 0;
                    END ELSE BEGIN
                        PurchLine."Reserv Qty. to Post Ship.Cont." := PurchLine."Reserv Qty. to Post Ship.Cont." + ReturnQtytoShip;
                        PurchLine."Return Qty. to Ship S.Cont." := 0;
                    END;
                    PurchLine.MODIFY;
                END;
            END;
        end;
    end;


    var
        Item: Record 27;
        PurchSetup: Record "Purchases & Payables Setup";

}