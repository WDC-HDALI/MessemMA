namespace MESSEM.MESSEM;
using Microsoft.Inventory.Posting;
using Microsoft.Purchases.Setup;
using Microsoft.Foundation.Navigate;
using Microsoft.Purchases.History;
using Microsoft.Purchases.Document;
using Microsoft.Utilities;
using Microsoft.Purchases.Posting;
using Microsoft.Foundation.NoSeries;
using Microsoft.Finance.GeneralLedger.Journal;
using Microsoft.Finance.GeneralLedger.Posting;
using Microsoft.Inventory.Journal;

codeunit 50004 "WDC Rebate Subsc Accounting"
{


    //********Champs à valider Feuille paiement
    [EventSubscriber(ObjectType::Page, 256, 'OnBeforeActionEvent', 'Post', false, false)]
    procedure OnBeforePostPaymentJournal(var Rec: Record 81)
    var
        ltext001: Label 'Please select the rows to post';
    begin
        Rec.SETRANGE("To Post", TRUE);
        IF Rec.ISEMPTY THEN
            ERROR(ltext001);
    end;

    [EventSubscriber(ObjectType::Page, 256, 'OnBeforeActionEvent', 'Post', false, false)]
    procedure OnBeforePostAndPrinPaymentJournal(var Rec: Record 81)
    var
        ltext001: Label 'Please select the rows to post';
    begin
        Rec.SETRANGE("To Post", TRUE);
        IF Rec.ISEMPTY THEN
            ERROR(ltext001);
    end;
    /////************Feuille Paiement

    [EventSubscriber(ObjectType::Codeunit, codeunit::"Gen. Jnl.-Post line", 'OnAfterInsertGLEntry', '', FALSE, FALSE)]
    local procedure OnAfterInsertGLEntry(GenJnlLine: Record "Gen. Journal Line"; CalcAddCurrResiduals: Boolean)
    begin
        // if GenJnlLine."Debit Amount" <> 0 Then
        //     InsertRebateEntry(GenJnlLine);
    end;
    //Linked by the navigate entries page(Posted purchase invoice)
    [EventSubscriber(ObjectType::Page, Page::Navigate, 'OnAfterFindPostedDocuments', '', FALSE, FALSE)]
    local procedure OnAfterFindPostedDocuments(var DocNoFilter: Text; var PostingDateFilter: Text; var DocumentEntry: Record "Document Entry")
    var
        lRebateEntry: record "WDC Rebate Entry";
    begin
        IF lRebateEntry.READPERMISSION THEN BEGIN
            lRebateEntry.RESET;
            lRebateEntry.SETCURRENTKEY("Document No.", "Posting Date");
            lRebateEntry.SETFILTER("Document No.", DocNoFilter);
            lRebateEntry.SETFILTER("Posting Date", PostingDateFilter);
            if lRebateEntry.FindFirst() Then begin
                DocumentEntry.InsertIntoDocEntry(Database::"WDC Rebate Entry", lRebateEntry.TableCaption(), lRebateEntry.Count);
            end;
        END;
    end;

    [EventSubscriber(ObjectType::Page, Page::Navigate, 'OnAfterShowRecords', '', FALSE, FALSE)]
    local procedure OnAfterShowRecords(var DocumentEntry: Record "Document Entry"; DocNoFilter: Text; PostingDateFilter: Text; ItemTrackingSearch: Boolean; ContactType: Enum "Navigate Contact Type"; ContactNo: Code[250]; ExtDocNo: Code[250])
    var
        lRebateEntry: record "WDC Rebate Entry";
    begin
        IF DocumentEntry."Table ID" = Database::"WDC Rebate Entry" then begin
            lRebateEntry.RESET;
            lRebateEntry.SETCURRENTKEY("Document No.", "Posting Date");
            lRebateEntry.SETFILTER("Document No.", DocNoFilter);
            lRebateEntry.SETFILTER("Posting Date", PostingDateFilter);
            if lRebateEntry.FindFirst() Then begin
                PAGE.Run(PAGE::"WDC Rebate Entries", lRebateEntry);
            end;
        end;


    end;


    [EventSubscriber(ObjectType::Codeunit, codeunit::"Gen. Jnl.-Post Batch", 'OnBeforePostGenJnlLine', '', FALSE, FALSE)]
    local procedure OnBeforePostGenJnlLine(var GenJournalLine: Record "Gen. Journal Line"; CommitIsSuppressed: Boolean; var Posted: Boolean; var GenJnlPostLine: Codeunit "Gen. Jnl.-Post Line"; var PostingGenJournalLine: Record "Gen. Journal Line")
    var
    begin
        GenJournalLine.GenJnlRebateSet := (GenJournalLine."Rebate Code" <> '');
    end;

    [EventSubscriber(ObjectType::Table, database::"Item Journal Line", 'OnAfterCopyItemJnlLineFromPurchLine', '', FALSE, FALSE)]
    local procedure OnAfterCopyItemJnlLineFromPurchLine(var ItemJnlLine: Record "Item Journal Line"; PurchLine: Record "Purchase Line")
    var

    begin
        ItemJnlLine."Rebate Accrual Amount (LCY)" := PurchLine."Accrual Amount (LCY)";
    end;

    [EventSubscriber(ObjectType::Codeunit, codeunit::"Copy Document Mgt.", 'OnAfterInitPurchLineFields', '', FALSE, FALSE)]
    local procedure OnAfterInitPurchLineFields(var PurchaseLine: Record "Purchase Line")
    var
    begin
        PurchaseLine."Accrual Amount (LCY)" := 0;
    end;

    procedure InsertRebateEntry(var GenJnlLine: Record 81)
    var
        RebateEntry: Record "WDC Rebate Entry";
        RebateEntry2: Record "WDC Rebate Entry";
        Currency: Record 4;
        ItemUOM: Record 5404;
        Item: Record 27;
        RebateDifference: Decimal;
        RemRebateDifference: Decimal;
        NewEntryNo: Integer;
        SumBaseQuantity: Decimal;
        SumBaseAmount: Decimal;
        SumAccrualAmountLCY: Decimal;
        CurrencyExchangeRates: Record 330;
        TotalValidEntries: Integer;
        EntryCounter: Integer;
    begin

        IF NOT (GenJnlLine.PurchaseRebateSet OR GenJnlLine.GenJnlRebateSet) THEN
            EXIT;

        GetPurchaseRebateAndLine(GenJnlLine);

        IF RebateEntry.FINDLAST THEN
            NewEntryNo := RebateEntry."Entry No." + 1
        ELSE
            NewEntryNo := 1;

        // Accrual
        RebateEntry.INIT;
        RebateEntry."Entry No." := NewEntryNo;
        RebateEntry."Posting Date" := GenJnlLine."Posting Date";
        RebateEntry."Document No." := GenJnlLine."Document No.";
        RebateEntry."Document Type" := GenJnlLine."Rebate Posted Doc Type";
        RebateEntry."Rebate Code" := GenJnlLine."Rebate Code";
        RebateEntry."Buy-from No." := GenJnlLine."Sell-to/Buy-from No.";
        RebateEntry."Bill-to/Pay-to No." := GenJnlLine."Bill-to/Pay-to No.";
        RebateEntry."External Document No." := GenJnlLine."External Document No.";


        // Accrual
        IF GenJnlLine.PurchaseRebateSet AND (GenJnlLine."Rebate Document Type" = GenJnlLine."Rebate Document Type"::Accrual) THEN BEGIN

            GenJnlLine.PurchaseRebateSet := FALSE;

            RebateEntry."Rebate Document Type" := RebateEntry."Rebate Document Type"::Accrual;


            RebateEntry."Currency Code" := PurchaseLine."Currency Code";
            RebateEntry."Base Quantity" := PurchaseLine."Qty. to Invoice";
            IF PurchaseLine."Document Type" = PurchaseLine."Document Type"::"Credit Memo" THEN BEGIN
                RebateEntry."Accrual Amount (LCY)" := GenJnlLine.Amount;
                RebateEntry."Base Amount" := -PurchaseLine."VAT Base Amount";
                RebateEntry."Base Quantity" := -RebateEntry."Base Quantity";
            END ELSE begin
                RebateEntry."Accrual Amount (LCY)" := GenJnlLine.Amount;
                RebateEntry."Base Amount" := PurchaseLine."VAT Base Amount";
            end;

            RebateEntry."Rebate Code" := PurchaseRebate."Rebate Code";
            RebateEntry."Vendor No." := PurchaseRebate."Vendor No.";
            RebateEntry."Accrual Value (LCY)" := PurchaseRebate."Accrual Value (LCY)";
            RebateEntry."Starting Date" := PurchaseRebate."Starting Date";
            RebateEntry."Ending Date" := PurchaseRebate."Ending Date";
            RebateEntry.Open := TRUE;
            RebateEntry."Document Line No." := PurchaseLine."Line No.";
        END;

        // Payment
        IF (GenJnlLine.PurchaseRebateSet) AND
           (GenJnlLine."Rebate Document Type" = GenJnlLine."Rebate Document Type"::Payment) THEN BEGIN

            IF GenJnlLine.PurchaseRebateSet THEN BEGIN

                RebateEntry."Rebate Code" := PurchaseLine."Rebate Code";
                RebateEntry."Currency Code" := PurchaseLine."Currency Code";
            END;

            RebateEntry."Rebate Document Type" := RebateEntry."Rebate Document Type"::Payment;
            RebateEntry."Closed by Entry No." := RebateEntry."Entry No.";

            IF RebateEntry."Currency Code" <> '' THEN BEGIN
                Currency.GET(RebateEntry."Currency Code");
                Currency.TESTFIELD("Amount Rounding Precision");
                RebateEntry."Rebate Amount (LCY)" := ROUND(
                  CurrencyExchangeRates.ExchangeAmtFCYToLCY(RebateEntry."Posting Date",
                    RebateEntry."Currency Code", GenJnlLine.Amount,
                    CurrencyExchangeRates.ExchangeRate(RebateEntry."Posting Date", RebateEntry."Currency Code")),
                  Currency."Amount Rounding Precision");
            END ELSE begin
                if GenJnlLine."Rebate Posted Doc Type" = GenJnlLine."Rebate Posted Doc Type"::"Credit Memo" then
                    RebateEntry."Rebate Amount (LCY)" := GenJnlLine.Amount
                else
                    RebateEntry."Rebate Amount (LCY)" := -GenJnlLine.Amount
            end;


            IF GenJnlLine.PurchaseRebateSet THEN BEGIN
                RebateEntry."Rebate Amount (LCY)" := -RebateEntry."Rebate Amount (LCY)";
                GenJnlLine.PurchaseRebateSet := FALSE;
            END;

            RebateEntry2.SETRANGE("Buy-from No.", GenJnlLine."Sell-to/Buy-from No.");
            RebateEntry2.SETRANGE("Rebate Code", RebateEntry."Rebate Code");
            RebateEntry2.SETRANGE("Rebate Document Type", RebateEntry2."Rebate Document Type"::Accrual);
            RebateEntry2.SETRANGE(Open, TRUE);
            IF RebateEntry2.FINDSET THEN BEGIN
                REPEAT
                    SumBaseQuantity += RebateEntry2."Base Quantity";
                    SumBaseAmount += RebateEntry2."Base Amount";
                    SumAccrualAmountLCY += RebateEntry2."Accrual Amount (LCY)";
                    TotalValidEntries := TotalValidEntries + 1;
                UNTIL RebateEntry2.NEXT <= 0;
            END;

            RebateDifference := -(SumAccrualAmountLCY + RebateEntry."Rebate Amount (LCY)");
            RemRebateDifference := RebateDifference;

            Currency.InitRoundingPrecision;

            IF RebateEntry2.FINDSET THEN
                REPEAT
                    EntryCounter := EntryCounter + 1;
                    IF TotalValidEntries = EntryCounter THEN
                        RebateEntry2."Rebate Difference (LCY)" := RemRebateDifference
                    ELSE
                        RebateEntry2."Rebate Difference (LCY)" :=
                          ROUND(RebateDifference * RebateEntry2."Accrual Amount (LCY)" / SumAccrualAmountLCY, Currency."Amount Rounding Precision");

                    RemRebateDifference := RemRebateDifference - RebateEntry2."Rebate Difference (LCY)";

                    RebateEntry2."Rebate Amount (LCY)" := RebateEntry2."Accrual Amount (LCY)" + RebateEntry2."Rebate Difference (LCY)";
                    RebateEntry2."Closed by Entry No." := RebateEntry."Entry No.";
                    RebateEntry2.Open := FALSE;
                    RebateEntry2.MODIFY;
                UNTIL RebateEntry2.NEXT <= 0;

            RebateEntry."Base Quantity" := -SumBaseQuantity;
            RebateEntry."Base Amount" := -SumBaseAmount;

        END;

        // Correction
        IF GenJnlLine.GenJnlRebateSet AND
          (GenJnlLine."Rebate Document Type" = GenJnlLine."Rebate Document Type"::Correction)
        THEN BEGIN
            GenJnlLine.GenJnlRebateSet := FALSE;

            RebateEntry."Rebate Document Type" := RebateEntry."Rebate Document Type"::Correction;
            RebateEntry."Rebate Code" := GenJnlLine."Rebate Code";
            RebateEntry."Correction Amount (LCY)" := GenJnlLine."Rebate Correction Amount (LCY)";
            RebateEntry."Correction Posted by Entry No." := RebateEntry."Entry No.";

            RebateEntry2.SETRANGE("Buy-from No.", RebateEntry."Buy-from No.");
            RebateEntry2.SETRANGE("Rebate Code", RebateEntry."Rebate Code");
            RebateEntry2.SETRANGE("Rebate Document Type", RebateEntry2."Rebate Document Type"::Accrual);
            IF NOT GenJnlLine."Include Open Rebate Entries" THEN
                RebateEntry2.SETRANGE(Open, FALSE);
            RebateEntry2.SETFILTER("Ending Date", '<%1', WORKDATE());
            IF RebateEntry2.FINDSET THEN BEGIN
                REPEAT
                    IF (RebateEntry2."Rebate Amount (LCY)" - RebateEntry2."Accrual Amount (LCY)") <> 0 THEN BEGIN
                        RebateEntry2."Correction Amount (LCY)" := -(RebateEntry2."Rebate Amount (LCY)" - RebateEntry2."Accrual Amount (LCY)");
                        RebateEntry2."Rebate Difference (LCY)" := 0;
                        RebateEntry2."Correction Posted by Entry No." := RebateEntry."Entry No.";
                        RebateEntry2."Correction Posted" := TRUE;
                        RebateEntry2.Open := FALSE;
                        RebateEntry2.MODIFY;
                    END;
                UNTIL RebateEntry2.NEXT <= 0;
            END;

        END;

        RebateEntry.INSERT;
    end;


    procedure GetPurchaseRebateAndLine(GenJnlLine: Record 81)
    var
        PurchRcptHeader2: Record 120;
        Item2: Record 27;
        RebateCode: Record "WDC Rebate Code";
        CurrExchRate: Record 330;
        RebateDate: Date;
        DummyDate: Date;
        RebateLineAmountLCY: Decimal;
    begin
        if PurchHeader.get(GenJnlLine."Rebate Posted Doc Type", GenJnlLine."Rebate Purchase Doc No.") then //HD10112024
            if PurchaseLine.get(GenJnlLine."Rebate Posted Doc Type", GenJnlLine."Rebate Purchase Doc No.", GenJnlLine."Line No.") then
                IF PurchaseLine."Receipt No." <> '' THEN BEGIN
                    PurchRcptHeader2.GET(PurchaseLine."Receipt No.");
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
        if Item2.get(PurchaseLine."No.") then begin
            PurchaseRebate.Reset();
            PurchaseRebate.SETRANGE("Vendor No.", PurchHeader."Buy-from Vendor No.");
            PurchaseRebate.SETRANGE(Code, Item2." Purchases Item Rebate Group");
            PurchaseRebate.SETFILTER("Starting Date", '<=%1|%2', RebateDate, DummyDate);
            PurchaseRebate.SETFILTER("Ending Date", '>=%1|%2', RebateDate, DummyDate);
            IF PurchaseRebate.FINDSET THEN;
        end;


    end;

    var
        PurchHeader: record 38;
        PurchaseLine: Record 39;
        PurchaseRebate: Record "WDC Purchase Rebate";
        PurchSetup: record "Purchases & Payables Setup";
}
