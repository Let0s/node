unit TestHelpers;

interface
uses
  EngineHelper, NodeInterface;

type

  TGetEvent = function(Sender: TObject): Variant of object;
  TGetEventWrapper = class(TEventWrapper)
  public
    constructor Create(Func: IJSFunction); override;
    function Event(Sender: TObject): Variant;
  end;

implementation

{ TGetEventWrapper }

constructor TGetEventWrapper.Create(Func: IJSFunction);
var
  TempMethod: TMethod;
begin
  inherited;
  TempMethod.Code := @TGetEventWrapper.Event;
  TempMethod.Data := Self;
  SetMethod(TempMethod);
end;

function TGetEventWrapper.Event(Sender: TObject): Variant;
begin
  Result := CallFunction([Sender]).AsVariant;
end;

initialization
RegisterEventWrapper(TypeInfo(TGetEvent), TGetEventWrapper);

finalization

end.
