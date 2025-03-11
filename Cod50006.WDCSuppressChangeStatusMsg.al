namespace Messem.Messem;

using Microsoft.Manufacturing.Document;

codeunit 50006 "WDC Suppress Change Status Msg"
{
    TableNo = "Production Order";

    trigger OnRun()
    begin

    end;

    procedure OnRun2(VAR RecPO: Record "Production Order")
    var
        ProdOrderStatusMgt: Codeunit "Prod. Order Status Management";
    begin
        //ProdOrderStatusMgt.SetSuppressMessages(SuppressMessages);
        ProdOrderStatusMgt.ChangeProdOrderStatus(RecPO, Enum::"Production Order Status".FromInteger(NewStatus), NewPostingDate, NewUpdateUnitCost);

        COMMIT;
    end;

    procedure Set(NewStatus2: Option Simulated,Planned,"Firm Planned",Released,Finished; NewPostingDate2: Date; NewUpdateUnitCost2: Boolean; SuppressMessages2: Boolean)
    begin
        NewStatus := NewStatus2;
        NewPostingDate := NewPostingDate2;
        NewUpdateUnitCost := NewUpdateUnitCost2;
        SuppressMessages := SuppressMessages2;
    end;

    var
        NewStatus: Option Simulated,Planned,"Firm Planned",Released,Finished;
        NewPostingDate: Date;
        NewUpdateUnitCost: Boolean;
        SuppressMessages: Boolean;
}
