namespace MESSEM.MESSEM;
using Microsoft.Inventory.Posting;
using Microsoft.Inventory.Ledger;
using Microsoft.Finance.GeneralLedger.Setup;
using Microsoft.Inventory.Item;
using Microsoft.Foundation.Enums;
using Microsoft.Inventory.Costing;
using Microsoft.Warehouse.Journal;
using Microsoft.Inventory.Tracking;
using Microsoft.Inventory.Journal;

codeunit 50003 "WDC subscribers Werehouse"
{

    //<<*********************Lot Attribut Fileds******************************************

    [EventSubscriber(ObjectType::Page, Page::"Item Tracking Lines", 'OnRegisterChangeOnAfterCreateReservEntry', '', false, false)]
    local procedure ItemTrackingLinesOnRegisterChangeOnAfterCreateReservEntry(var ReservEntry: Record "Reservation Entry"; OldTrackingSpecification: Record "Tracking Specification")
    begin

        ReservEntry.PFD := OldTrackingSpecification.PFD;
        ReservEntry.Variety := OldTrackingSpecification.Variety;
        ReservEntry.BRIX := OldTrackingSpecification.Brix;
        ReservEntry."Package Number" := OldTrackingSpecification."Package Number";
        ReservEntry.Place := OldTrackingSpecification.Place;
        ReservEntry.modify;
    end;

    [EventSubscriber(ObjectType::Page, Page::"Item Tracking Lines", 'OnAfterEntriesAreIdentical', '', FALSE, FALSE)]
    local procedure OnAfterEntriesAreIdentical(ReservEntry1: Record "Reservation Entry"; ReservEntry2: Record "Reservation Entry"; var IdenticalArray: array[2] of Boolean)

    begin
        IdenticalArray[2] :=
        (ReservEntry1.PFD = ReservEntry2.PFD) AND
        (ReservEntry1.Variety = ReservEntry2.Variety) AND
        (ReservEntry1.BRIX = ReservEntry2.Brix) AND
        (ReservEntry1."Package Number" = ReservEntry2."Package Number") AND
        (ReservEntry1.Place = ReservEntry2.Place)
    end;

    [EventSubscriber(ObjectType::Page, Page::"Item Tracking Lines", 'OnAfterMoveFields', '', FALSE, FALSE)]
    local procedure OnAfterMoveFields(var TrkgSpec: Record "Tracking Specification"; var ReservEntry: Record "Reservation Entry")

    begin
        ReservEntry.PFD := TrkgSpec.PFD;
        ReservEntry.Variety := TrkgSpec.Variety;
        ReservEntry.BRIX := TrkgSpec.Brix;
        ReservEntry."Package Number" := TrkgSpec."Package Number";
        ReservEntry.Place := TrkgSpec.Place;
    end;

    [EventSubscriber(ObjectType::Page, Page::"Item Tracking Lines", 'OnAfterCopyTrackingSpec', '', FALSE, FALSE)]
    local procedure OnAfterCopyTrackingSpec(var SourceTrackingSpec: Record "Tracking Specification"; var DestTrkgSpec: Record "Tracking Specification")

    begin
        DestTrkgSpec.PFD := SourceTrackingSpec.PFD;
        DestTrkgSpec.Variety := SourceTrackingSpec.Variety;
        DestTrkgSpec.BRIX := SourceTrackingSpec.Brix;
        DestTrkgSpec."Package Number" := SourceTrackingSpec."Package Number";
        DestTrkgSpec.Place := SourceTrackingSpec.Place;
    end;

    [EventSubscriber(ObjectType::Table, DATABASE::"Tracking Specification", 'OnAfterValidateEvent', "Lot No.", FALSE, FALSE)]
    local procedure OnInsertRecordOnBeforeTempItemTrackLineInsert(var Rec: Record "Tracking Specification")

    begin
        Rec.PFD := '';
        Rec.Variety := '';
        Rec.BRIX := '';
        Rec."Package Number" := 0;
        Rec.Place := '';
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Item Jnl.-Post Line", 'OnBeforeInsertSetupTempSplitItemJnlLine', '', false, false)]
    local procedure ItemJnlPostLineOnBeforeInsertSetupTempSplitItemJnlLine(var TempTrackingSpecification: Record "Tracking Specification"; var TempItemJournalLine: Record "Item Journal Line")
    begin
        TempItemJournalLine.PFD := TempTrackingSpecification.PFD;
        TempItemJournalLine.Variety := TempTrackingSpecification.Variety;
        TempItemJournalLine.BRIX := TempTrackingSpecification.Brix;
        TempItemJournalLine."Package Number" := TempTrackingSpecification."Package Number";
        TempItemJournalLine.Place := TempTrackingSpecification.Place;
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Item Jnl.-Post Line", 'OnAfterInitItemLedgEntry', '', false, false)]
    local procedure ItemJnlPostLineOnAfterInitItemLedgEntry(var NewItemLedgEntry: Record "Item Ledger Entry"; ItemJournalLine: Record "Item Journal Line")
    var
        lLotInformation: Record "Lot No. Information";
    begin
        NewItemLedgEntry.PFD := ItemJournalLine.PFD;
        NewItemLedgEntry.Variety := ItemJournalLine.Variety;
        NewItemLedgEntry.BRIX := ItemJournalLine.Brix;
        NewItemLedgEntry."Package Number" := ItemJournalLine."Package Number";
        NewItemLedgEntry.Place := ItemJournalLine.Place;
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Item Tracking Management", 'OnAfterCreateLotInformation', '', false, false)]
    local procedure OnAfterCreateLotInformation(var LotNoInfo: Record "Lot No. Information"; var TrackingSpecification: Record "Tracking Specification")
    var
    begin
        LotNoInfo.PFD := TrackingSpecification.PFD;
        LotNoInfo.Variety := TrackingSpecification.Variety;
        LotNoInfo.BRIX := TrackingSpecification.Brix;
        LotNoInfo."Package Number" := TrackingSpecification."Package Number";
        LotNoInfo.Place := TrackingSpecification.Place;
        LotNoInfo.Modify();
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Item Jnl.-Post Line", 'OnBeforePostItemJnlLine', '', false, false)]
    local procedure GetCorrectionfields(var ItemJournalLine: Record "Item Journal Line")
    var
        OldItemLedgerEntry: Record "Item Ledger Entry";
    begin
        if not ItemJournalLine.Correction then
            exit;
        if not OldItemLedgerEntry.get(ItemJournalLine."Applies-from Entry") then
            if not OldItemLedgerEntry.get(ItemJournalLine."Applies-to Entry") then
                exit;
        ItemJournalLine.PFD := OldItemLedgerEntry.PFD;
        ItemJournalLine.Variety := OldItemLedgerEntry.Variety;
        ItemJournalLine.BRIX := OldItemLedgerEntry.Brix;
        ItemJournalLine."Package Number" := OldItemLedgerEntry."Package Number";
        ItemJournalLine.Place := OldItemLedgerEntry.Place;
    end;

    //>>**************************Lot Attribut Fileds************************

    [EventSubscriber(ObjectType::Table, DATABASE::"Item Journal Line", 'OnAfterSetupNewLine', '', false, false)]
    local procedure OnAfterSetupNewLine(var ItemJournalLine: Record "Item Journal Line"; var LastItemJournalLine: Record "Item Journal Line"; ItemJournalTemplate: Record "Item Journal Template"; ItemJnlBatch: Record "Item Journal Batch")
    var
    begin
        if ItemJnlBatch."Source Type by Default" <> ItemJnlBatch."Source Type by Default"::" " Then
            ItemJournalLine."Source Type" := ItemJnlBatch."Source Type by Default";
        if ItemJnlBatch."Entry Type" <> ItemJnlBatch."Entry Type"::" " then
            ItemJournalLine."Entry Type" := ItemJnlBatch."Entry Type";
    end;



}
