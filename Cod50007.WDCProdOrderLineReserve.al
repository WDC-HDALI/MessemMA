namespace Messem.Messem;
using Microsoft.Manufacturing.Document;
using Microsoft.Inventory.Tracking;

codeunit 50007 "WDC Prod. Order Line-Reserve"
{
    procedure CallItemTracking2(VAR ProdOrderLine: Record "Prod. Order Line"; VAR pTempTrackingSpecification: Record "Tracking Specification" temporary)
    var
        TrackingSpecification: Record "Tracking Specification";
        ItemTrackingForm: Page "Item Tracking Lines";
        ItemTrackingMgt: Codeunit "Item Tracking Management";
    begin
        ProdOrderLine.TESTFIELD("Item No.");
        InitTrackingSpecification(ProdOrderLine, TrackingSpecification);

        //ItemTrackingForm.SetContainerRequired(ProdOrderLine."Item No.", ProdOrderLine."Location Code", DATABASE::"Prod. Order Line");
        ItemTrackingForm.SetProdTrackingSource(DATABASE::"Prod. Order Line", ProdOrderLine.Status.AsInteger(),
                                               ProdOrderLine."Prod. Order No.", ProdOrderLine."Line No.", 0);

        ItemTrackingForm.SetSourceSpec(TrackingSpecification, ProdOrderLine."Due Date");
        pTempTrackingSpecification.DELETEALL;
        ItemTrackingForm.GetSource(pTempTrackingSpecification);
    end;

    procedure InitTrackingSpecification(VAR ProdOrderLine: Record "Prod. Order Line"; VAR TrackingSpecification: Record "Tracking Specification")
    begin
        TrackingSpecification.INIT;
        TrackingSpecification."Source Type" := DATABASE::"Prod. Order Line";
        //WITH ProdOrderLine DO BEGIN
        TrackingSpecification."Item No." := ProdOrderLine."Item No.";
        TrackingSpecification."Location Code" := ProdOrderLine."Location Code";
        TrackingSpecification.Description := ProdOrderLine.Description;
        TrackingSpecification."Variant Code" := ProdOrderLine."Variant Code";
        TrackingSpecification."Source Subtype" := ProdOrderLine.Status.AsInteger();
        TrackingSpecification."Source ID" := ProdOrderLine."Prod. Order No.";
        TrackingSpecification."Source Batch Name" := '';
        TrackingSpecification."Source Prod. Order Line" := ProdOrderLine."Line No.";
        TrackingSpecification."Source Ref. No." := 0;
        TrackingSpecification."Quantity (Base)" := ProdOrderLine."Quantity (Base)";
        TrackingSpecification."Qty. to Handle" := ProdOrderLine."Remaining Quantity";
        TrackingSpecification."Qty. to Handle (Base)" := ProdOrderLine."Remaining Qty. (Base)";
        TrackingSpecification."Qty. to Invoice" := ProdOrderLine."Remaining Quantity";
        TrackingSpecification."Qty. to Invoice (Base)" := ProdOrderLine."Remaining Qty. (Base)";
        TrackingSpecification."Quantity Handled (Base)" := ProdOrderLine."Finished Qty. (Base)";
        TrackingSpecification."Quantity Invoiced (Base)" := ProdOrderLine."Finished Qty. (Base)";
        TrackingSpecification."Qty. per Unit of Measure" := ProdOrderLine."Qty. per Unit of Measure";
        // TrackingSpecification."Unit of Measure Code" := "Unit of Measure Code";
        // TrackingSpecification."Shipment Unit" := TempTrackingSpecification."Shipment Unit";
        // TrackingSpecification."Qty. per Shipment Unit" := TempTrackingSpecification."Qty. per Shipment Unit";
        // TrackingSpecification."Shipment Container" := TempTrackingSpecification."Shipment Container";
        // TrackingSpecification."Qty. per Shipment Container" := TempTrackingSpecification."Qty. per Shipment Container";
        // TrackingSpecification."Net Weight" := TempTrackingSpecification."Net Weight";
        // TrackingSpecification."Zone Code" := TempTrackingSpecification."Zone Code";
        //END;
    end;
}
