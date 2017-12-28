unit EventWrapper;

interface

uses
  Classes, NodeInterface, Generics.Collections, RTTI, TypInfo;

type
  TEventWrapper = class(TObject)
  private
    FFunction: IJSFunction;
    FMethod: TMethod;
  protected
    property JSFunction: IJSFunction read FFunction;
    procedure SetMethod(NewMethod: TMethod);
  public
    constructor Create(Func: IJSFunction); virtual;
    property Method: TMethod read FMethod;
  end;

  TEventWrapperClass = class of TEventWrapper;

  TNotifyEventWrapper = class(TEventWrapper)
  public
    constructor Create(Func: IJSFunction); override;
    procedure Event(Sender: TObject);
  end;

  TEventWrapperList = class(TObjectList<TEventWrapper>)
  end;

  //returns false if event already registered
  function RegisterEventWrapper(Event: PTypeInfo;
    Wrapper: TEventWrapperClass): boolean;
  function GetEventWrapper(Event: PTypeInfo): TEventWrapperClass;

implementation

var
  EventWrapperClassList: TDictionary<PTypeInfo, TEventWrapperClass>;


function RegisterEventWrapper(Event: PTypeInfo;
  Wrapper: TEventWrapperClass): boolean;
begin
  Result := False;
  if not EventWrapperClassList.ContainsKey(Event) then
  begin
    EventWrapperClassList.Add(Event, Wrapper);
    Result := True;
  end;
end;

function GetEventWrapper(Event: PTypeInfo): TEventWrapperClass;
begin
  if not EventWrapperClassList.TryGetValue(Event, Result) then
    Result := nil;
end;

{ TEventWrapper }

constructor TEventWrapper.Create(Func: IJSFunction);
begin
  FFunction := Func;
end;

procedure TEventWrapper.SetMethod(NewMethod: TMethod);
begin
  FMethod := NewMethod;
end;

{ TNotifyEventWrapper }

constructor TNotifyEventWrapper.Create(Func: IJSFunction);
var
  TempMethod: TMethod;
begin
  inherited;
  TempMethod.Code := @TNotifyEventWrapper.Event;
  TempMethod.Data := Self;
  SetMethod(TempMethod);
end;

procedure TNotifyEventWrapper.Event(Sender: TObject);
begin
  JSFunction.Call(nil);
end;


initialization
  EventWrapperClassList := TDictionary<PTypeInfo, TEventWrapperClass>.Create;
  RegisterEventWrapper(TypeInfo(TNotifyEvent), TNotifyEventWrapper);

finalization
  EventWrapperClassList.Free;

end.
