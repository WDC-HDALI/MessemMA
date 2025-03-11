codeunit 50005 "WDC Rebate Subsc. Purchase"
{
    // [EventSubscriber(ObjectType::Codeunit, codeunit::"Purch.-Post", 'OnAfterUpdatePurchLineBeforePost', '', FALSE, FALSE)]
    // local procedure OnAfterUpdatePurchLineBeforePost_Bonus(var PurchaseLine: Record "Purchase Line"; WhseShip: Boolean; WhseReceive: Boolean; PurchaseHeader: Record "Purchase Header"; RoundingLineInserted: Boolean)
    // var
    [EventSubscriber(ObjectType::Codeunit, codeunit::"Purch.-Post", 'OnAfterPostInvoice', '', FALSE, FALSE)]

    local procedure OnAfterPostInvoice(var PurchHeader: Record "Purchase Header"; var GenJnlPostLine: Codeunit "Gen. Jnl.-Post Line"; TotalPurchLine: Record "Purchase Line"; TotalPurchLineLCY: Record "Purchase Line"; CommitIsSupressed: Boolean; var VendorLedgerEntry: Record "Vendor Ledger Entry")
    var
        lPurchaseLine: record "Purchase Line";
    begin
        lPurchaseLine.Reset();
        lPurchaseLine.SetRange("Document Type", PurchHeader."Document Type");
        lPurchaseLine.SetRange("Document No.", PurchHeader."No.");
        lPurchaseLine.SetRange(Type, lPurchaseLine.Type::Item);
        if lPurchaseLine.FindFirst() then
            repeat
                IF lPurchaseLine."Document Type" IN [lPurchaseLine."Document Type"::"Credit Memo", lPurchaseLine."Document Type"::Invoice] THEN
                    CalcRebateValue(PurchHeader, lPurchaseLine, true);
                IF lPurchaseLine."Document Type" = lPurchaseLine."Document Type"::"Credit Memo" THEN
                    CreateRebatePayment(PurchHeader, lPurchaseLine);
            until lPurchaseLine.Next() = 0;
    end;

    [EventSubscriber(ObjectType::Codeunit, codeunit::"Purch.-Post", 'OnPostItemJnlLineOnAfterSetFactor', '', FALSE, FALSE)]
    local procedure OnPostItemJnlLineOnAfterSetFactor(var PurchaseLine: Record "Purchase Line"; var Factor: Decimal; var GenJnlLineExtDocNo: Code[35]; var ItemJournalLine: Record "Item Journal Line")
    var
    begin
        ItemJournalLine."Rebate Accrual Amount (LCY)" :=
              (ItemJournalLine."Rebate Accrual Amount (LCY)" * Factor + RemRebateAmountLCY);
        RemRebateAmountLCY := ItemJournalLine."Rebate Accrual Amount (LCY)" - ROUND(ItemJournalLine."Rebate Accrual Amount (LCY)");
        ItemJournalLine."Rebate Accrual Amount (LCY)" := ROUND(ItemJournalLine."Rebate Accrual Amount (LCY)");
    end;

    [EventSubscriber(ObjectType::Table, DataBase::"Item Journal Line", 'OnAfterCopyItemJnlLineFromPurchHeader', '', FALSE, FALSE)]
    local procedure OnAfterCopyItemJnlLineFromPurchHeader(var ItemJnlLine: Record "Item Journal Line"; PurchHeader: Record "Purchase Header")
    var
    begin
        case PurchHeader."Document Type" of
            PurchHeader."Document Type"::Quote:
                ItemJnlLine."Source Subtype" := ItemJnlLine."Source Subtype"::"0";
            PurchHeader."Document Type"::Order:
                ItemJnlLine."Source Subtype" := ItemJnlLine."Source Subtype"::"1";
            PurchHeader."Document Type"::Invoice:
                ItemJnlLine."Source Subtype" := ItemJnlLine."Source Subtype"::"2";
            PurchHeader."Document Type"::"Credit Memo":
                ItemJnlLine."Source Subtype" := ItemJnlLine."Source Subtype"::"3";
            PurchHeader."Document Type"::"Blanket Order":
                ItemJnlLine."Source Subtype" := ItemJnlLine."Source Subtype"::"4";
            PurchHeader."Document Type"::"Return Order":
                ItemJnlLine."Source Subtype" := ItemJnlLine."Source Subtype"::"5";
        end;
    end;


    [EventSubscriber(ObjectType::Codeunit, codeunit::"Item Jnl.-Post Line", 'OnAfterInitItemLedgEntry', '', FALSE, FALSE)]
    local procedure OnAfterInitItemLedgEntry(var NewItemLedgEntry: Record "Item Ledger Entry"; var ItemJournalLine: Record "Item Journal Line"; var ItemLedgEntryNo: Integer)
    var
    begin
        NewItemLedgEntry."Source Subtype" := ItemJournalLine."Source Subtype";
    end;

    [EventSubscriber(ObjectType::Codeunit, codeunit::"Item Jnl.-Post Line", 'OnInitValueEntryOnBeforeSetDocumentLineNo', '', FALSE, FALSE)]
    local procedure OnInitValueEntryOnBeforeSetDocumentLineNo(ItemJournalLine: Record "Item Journal Line"; var ItemLedgerEntry: Record "Item Ledger Entry"; var ValueEntry: Record "Value Entry")
    var
    begin

        if ValueEntry."Item Ledger Entry Type" = ValueEntry."Item Ledger Entry Type"::Purchase then begin
            ValueEntry."Source Subtype" := ItemJournalLine."Source Subtype";
            IF ValueEntry."Source Subtype" = ValueEntry."Source Subtype"::"2" THEN
                RebateSignFactor := 1
            ELSE
                RebateSignFactor := -1;
        end;
        ValueEntry."Rebate Accrual Amount (LCY)" := RebateSignFactor * ItemJournalLine."Rebate Accrual Amount (LCY)";
    end;


    [EventSubscriber(ObjectType::Codeunit, codeunit::"Item Jnl.-Post Line", 'OnInsertVarValueEntryOnAfterInitValueEntryFields', '', FALSE, FALSE)]
    local procedure OnInsertVarValueEntryOnAfterInitValueEntryFields(var ValueEntry: record "Value Entry")
    var
    begin
        ValueEntry."Rebate Accrual Amount (LCY)" := 0;
    end;

    [EventSubscriber(ObjectType::Codeunit, codeunit::"Item Jnl.-Post Line", 'OnAfterSetupTempSplitItemJnlLineSetQty', '', FALSE, FALSE)]
    local procedure OnAfterSetupTempSplitItemJnlLineSetQty(var TempSplitItemJnlLine: Record "Item Journal Line" temporary; ItemJournalLine: Record "Item Journal Line"; SignFactor: Integer; var TempTrackingSpecification: Record "Tracking Specification" temporary)
    var
        lGLSetup: record "General Ledger Setup";
    begin
        lGLSetup.get;
        if SignFactor < 1 then   //à vérifier FloatingFactor lors le test car il est remplacé par SignFactor 
            TempSplitItemJnlLine."Rebate Accrual Amount (LCY)" := ROUND(ItemJournalLine."Rebate Accrual Amount (LCY)" * SignFactor, lGLSetup."Amount Rounding Precision")

        else
            TempSplitItemJnlLine."Rebate Accrual Amount (LCY)" := ItemJournalLine."Rebate Accrual Amount (LCY)";
    end;

    local procedure CalcRebateValue(PurchHeader: Record 38; var PurchLine: Record 39; PostAccrual: Boolean)
    var
        Item2: Record 27;
        Vendor2: Record 23;
        PurchaseRebate: Record "WDC Purchase Rebate";
        LineAmountLCY: Decimal;
    begin
        IF (PurchLine.Type <> PurchLine.Type::Item) THEN
            EXIT;

        Vendor2.GET(PurchHeader."Pay-to Vendor No.");
        Item2.GET(PurchLine."No.");

        LineAmountLCY += AddRebateValues(PurchHeader, PurchLine, Vendor2."No.", Item2." Purchases Item Rebate Group", PostAccrual);

        //IF NOT PostAccrual THEN
        PurchLine."Accrual Amount (LCY)" := LineAmountLCY;
    end;

    local procedure AddRebateValues(PurchHeader: Record 38; PurchLine: Record 39; PurchaseCode: Code[20]; "Code": Code[20]; PostAccrual: Boolean) TotalRebateAmountLCY: Decimal
    var
        PurchRcptHeader2: Record 120;
        PurchaseRebate: Record "WDC Purchase Rebate";
        Item2: Record 27;
        ItemUOM: Record 5404;
        ItemUOM2: Record 5404;
        RebateCode: Record "WDC Rebate Code";
        CurrExchRate: Record 330;
        RebateDate: Date;
        DummyDate: Date;
        RebateLineAmountLCY: Decimal;
    begin
        IF PurchLine."Receipt No." <> '' THEN BEGIN
            PurchRcptHeader2.GET(PurchLine."Receipt No.");
            IF PurchSetup."Date Price-and Discount Def." = PurchSetup."Date Price-and Discount Def."::"Order Date" THEN
                RebateDate := PurchRcptHeader2."Order Date"
            ELSE
                RebateDate := PurchRcptHeader2."Expected Receipt Date";
        END ELSE BEGIN
            IF PurchSetup."Date Price-and Discount Def." = PurchSetup."Date Price-and Discount Def."::"Order Date" THEN
                RebateDate := PurchHeader."Order Date"
            ELSE
                RebateDate := PurchHeader."Expected Receipt Date";
        END;

        PurchaseRebate.SETRANGE("Vendor No.", PurchaseCode);
        PurchaseRebate.SETRANGE(Code, Code);
        PurchaseRebate.SETFILTER("Starting Date", '<=%1|%2', RebateDate, DummyDate);
        PurchaseRebate.SETFILTER("Ending Date", '>=%1|%2', RebateDate, DummyDate);
        IF PurchaseRebate.FINDSET THEN
            REPEAT
                RebateLineAmountLCY := 0;
                RebateCode.GET(PurchaseRebate."Rebate Code");
                IF PurchHeader."Currency Code" = RebateCode."Currency Code" THEN
                    RebateLineAmountLCY := PurchLine."Qty. to Invoice (Base)" * PurchaseRebate."Accrual Value (LCY)";
                TotalRebateAmountLCY := TotalRebateAmountLCY + RebateLineAmountLCY;

                IF PostAccrual THEN
                    IF RebateLineAmountLCY <> 0 THEN begin
                        CreateRebateGenJnlLine(PurchHeader, PurchLine, PurchaseRebate, RebateLineAmountLCY);
                    end;
            UNTIL PurchaseRebate.NEXT <= 0;
    end;


    local procedure CreateRebateGenJnlLine(PurchHeader: Record 38; PurchLine: Record 39; PurchaseRebate: Record "WDC Purchase Rebate"; RebateLineAmountLCY: Decimal)
    var
        RebateCode: Record "WDC Rebate Code";
        GeneralPostingSetup: Record 252;
        GenJournalTemplate: Record 80;
        GenJournalBatch: Record 232;
        LineNo: Integer;
        GenJnlLine: Record 81;
    begin
        PurchaseRebate.TESTFIELD("Rebate Code");
        RebateCode.GET(PurchaseRebate."Rebate Code");
        RebateCode.TESTFIELD("Rebate GL-Acc. No.");

        GeneralPostingSetup.GET(PurchLine."Gen. Bus. Posting Group", PurchLine."Gen. Prod. Posting Group");
        GeneralPostingSetup.TESTFIELD("Purchase Rebate Account");

        GenJournalTemplate.SETRANGE(Type, GenJournalTemplate.Type::Purchases);
        GenJournalTemplate.FINDFIRST;

        GenJournalBatch.SETRANGE("Journal Template Name", GenJournalTemplate.Name);
        GenJournalBatch.FINDFIRST;
        LineNo := PurchLine."Line No.";
        //LineNo := GetNextLineNo(GenJournalTemplate.Name, GenJournalBatch.Name);

        GenJnlLine.INIT;
        GenJnlLine.VALIDATE("Journal Template Name", GenJournalTemplate.Name);
        GenJnlLine.VALIDATE("Journal Batch Name", GenJournalBatch.Name);
        GenJnlLine."Line No." := LineNo;
        //LineNo := LineNo + 10000;
        GetPostedDocInformations(PurchHeader."No.", PurchHeader."Document Type");
        GenJnlLine.VALIDATE("Posting Date", PurchHeader."Posting Date");
        GenJnlLine.VALIDATE("Document Type", PurchHeader."Document Type");
        GenJnlLine.VALIDATE("Document No.", GenJnlLineDocNo); //PurchHeader."No."); //GenJnlLineDocNo);//HD10112024
        GenJnlLine."Rebate Purchase Doc No." := PurchHeader."No.";
        GenJnlLine.VALIDATE("Account Type", GenJnlLine."Account Type"::"G/L Account");
        GenJnlLine.VALIDATE("Account No.", RebateCode."Rebate GL-Acc. No.");
        GenJnlLine.VALIDATE(Description, COPYSTR(STRSUBSTNO('%1 %2 %3 %4', TextSI009, PurchHeader."Pay-to Vendor No.",
          TextSI010, PurchHeader."Posting No."), 1, 50));
        IF PurchLine."Document Type" = PurchLine."Document Type"::Invoice THEN
            GenJnlLine.VALIDATE("Credit Amount", -RebateLineAmountLCY)
        ELSE
            GenJnlLine.VALIDATE("Debit Amount", -RebateLineAmountLCY);
        IF GenJnlLine.Amount = 0 THEN
            EXIT;
        GenJnlLine.VALIDATE("Bal. Account Type", GenJnlLine."Bal. Account Type"::"G/L Account");
        GenJnlLine.VALIDATE("Bal. Account No.", GeneralPostingSetup."Purchase Rebate Account");
        GenJnlLine.VALIDATE("Sell-to/Buy-from No.", PurchLine."Buy-from Vendor No.");
        GenJnlLine.VALIDATE("Bill-to/Pay-to No.", PurchLine."Pay-to Vendor No.");
        GenJnlLine."Source Code" := GenJournalTemplate."Source Code";
        GenJnlLine."External Document No." := GenJnlLineExtDocNo;
        GenJnlLine."Shortcut Dimension 1 Code" := PurchLine."Shortcut Dimension 1 Code";
        GenJnlLine."Shortcut Dimension 2 Code" := PurchLine."Shortcut Dimension 2 Code";
        GenJnlLine."Dimension Set ID" := PurchLine."Dimension Set ID";
        GenJnlLine."Rebate Document Type" := GenJnlLine."Rebate Document Type"::Accrual;
        GenJnlLine.PurchaseRebateSet := true;
        GenJnlLine."Rebate Code" := PurchaseRebate.Code;
        GenJnlLine."Rebate Posted Doc Type" := PurchLine."Document Type";
        CODEUNIT.RUN(CODEUNIT::"Adjust Gen. Journal Balance", GenJnlLine);
        if GenJnlLine."Credit Amount" <> 0 Then
            SubscriberAccounting.InsertRebateEntry(GenJnlLine);
        GenJnlPostLine.RunWithCheck(GenJnlLine);

    end;

    procedure CreateRebatePayment(PurchHeader: Record 38; PurchLine: Record 39)
    var
        GenJnlLine: Record 81;
    begin
        IF (PurchLine.Type <> PurchLine.Type::"G/L Account") OR
           (PurchLine."Rebate Code" = '') THEN
            EXIT;

        GenJnlLine.INIT;
        GenJnlLine."Posting Date" := PurchHeader."Posting Date";
        GenJnlLine."Document No." := PurchCrMemoHeader."No.";
        GenJnlLine."Document Type" := GenJnlLine."Document Type"::"Credit Memo";
        GenJnlLine."Sell-to/Buy-from No." := PurchLine."Buy-from Vendor No.";
        GenJnlLine."Bill-to/Pay-to No." := PurchLine."Pay-to Vendor No.";
        GenJnlLine."External Document No." := GenJnlLineExtDocNo;
        GenJnlLine."Account No." := PurchLine."No.";
        GenJnlLine.Amount := PurchLine."Line Amount";
        GenJnlLine."Rebate Document Type" := GenJnlLine."Rebate Document Type"::Payment;
        GenJnlLine.PurchasePaymentSet := TRUE;//, GenJnlLine, PurchLine); //HD01 Replace Variable PurchasePaymentSet by filed in table
        WDCAccountingSubscribers.InsertRebateEntry(GenJnlLine);
    end;

    procedure GetPostedDocInformations(pDocNoToPost: code[20]; pDocumentType: enum "Purchase Document Type")
    var
    begin
        If pDocumentType = pDocumentType::Invoice then Begin
            PurchInvheader.reset;
            PurchInvheader.SetCurrentKey("No.");
            PurchInvheader.SetRange("Pre-Assigned No.", pDocNoToPost);
            if PurchInvheader.FindLast() then
                GenJnlLineDocNo := PurchInvheader."No.";
        End else begin
            PurchCredMemHeader.reset;
            PurchCredMemHeader.SetCurrentKey("No.");
            PurchCredMemHeader.SetRange("Pre-Assigned No.", pDocNoToPost);
            if PurchCredMemHeader.FindLast() then
                GenJnlLineDocNo := PurchCredMemHeader."No.";
        end;
    end;


    local procedure GetNextLineNo(JournalTemplateName: Code[10]; JournalBatchName: Code[10]): Integer
    var
        GenJnlLine: Record 81;
    begin
        GenJnlLine.SETRANGE("Journal Template Name", JournalTemplateName);
        GenJnlLine.SETRANGE("Journal Batch Name", JournalBatchName);
        IF GenJnlLine.FINDLAST THEN
            EXIT(GenJnlLine."Line No." + 10000)
        ELSE
            EXIT(10000);
    end;

    var
        PurchSetup: Record "Purchases & Payables Setup";
        PurchInvheader: record 122;
        PurchCredMemHeader: record 124;
        GenJnlPostLine: Codeunit 12;
        WDCAccountingSubscribers: Codeunit "WDC Rebate Subsc Accounting";
        GenJnlLineDocNo: Code[20];
        GenJnlLineExtDocNo: Code[35];
        TextSI009: TextConst ENU = 'Vendor', FRA = 'Fournisseur';
        TextSI010: TextConst ENU = 'Invoice', FRA = 'Facture';
        PurchCrMemoHeader: Record 124;
        RemRebateAmountLCY: Decimal;
        RebateSignFactor: Decimal;
        SubscriberAccounting: Codeunit 50004;
}