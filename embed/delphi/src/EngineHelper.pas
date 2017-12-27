unit EngineHelper;

interface

uses
  NodeInterface, EventWrapper, RTTI, TypInfo, Generics.Collections;

type
  // It will collect all objects, were created by script
  TGarbageCollector = class(TObject)
  private
    FObjectList: TObjectList<TObject>;
    FCallbackList: TObjectList<TEventWrapper>;
  public
    constructor Create();
  end;

  function TValueToJSValue(value: TValue; Engine: INodeEngine): IJSValue;

  function JSValueToTValue(value: IJSValue; typ: TRttiType): TValue;
  function JSValueToMethod(value: IJSValue; typ: TRttiType): TValue;

var
  Context: TRttiContext;

implementation

function TValueToJSValue(value: TValue; Engine: INodeEngine): IJSValue;
begin
  Result := nil;
  case value.Kind of
    tkUnknown: ;
    tkInteger: Result := Engine.NewInt32(value.AsInteger);
    tkChar, tkString, tkWChar, tkLString, tkWString, tkUString:
      Result := Engine.NewString(StringToPUtf8Char(value.ToString));
    tkEnumeration:
      if value.IsType<Boolean> then
        Result := Engine.NewBool(value.AsBoolean)
      else
        Result := Engine.NewInt32(value.AsOrdinal);
    tkFloat: Result := Engine.NewNumber(value.AsExtended);
    tkSet: ;
    tkClass: Result := Engine.NewDelphiObject(value.AsObject,
                                              value.AsObject.ClassType);
    tkMethod: ;
    tkVariant: ;
    tkArray: ;
    tkRecord: ;
    tkInterface: ;
    tkInt64: ;
    tkDynArray: ;
    tkClassRef: ;
    tkPointer: ;
    tkProcedure: ;
  end;
end;


function JSValueToTValue(value: IJSValue; typ: TRttiType): TValue;
begin
  Result := TValue.Empty;
  case typ.TypeKind of
    tkUnknown: ;
    tkInteger: Result := value.AsInt32;
    tkChar, tkString, tkWChar, tkLString, tkWString, tkUString:
      Result := PUtf8CharToString(value.AsString);
    tkEnumeration:
      if typ.Handle = TypeInfo(Boolean) then
        Result := value.AsBool
      else
        Result := TValue.FromOrdinal(typ.Handle, value.AsInt32);
    tkFloat: Result := value.AsNumber;
    tkSet: ;
    tkClass: Result := value.AsDelphiObject.GetDelphiObject;
    tkMethod: Result := JSValueToMethod(value, typ);
    tkVariant: ;
    tkArray: ;
    tkRecord: ;
    tkInterface: ;
    tkInt64: ;
    tkDynArray: ;
    tkClassRef: ;
    tkPointer: ;
    tkProcedure: ;
  end;
end;

function JSValueToMethod(value: IJSValue; typ: TRttiType): TValue;
var
  EventWrapper: TEventWrapper;
begin
  Result := TValue.Empty;
  if value.IsFunction then
  begin
    EventWrapper := GetEventWrapper(typ.Handle).Create(value.AsFunction);
    TValue.Make(@EventWrapper.Method, typ.Handle, Result);
  end;
end;

{ TGarbageCollector }

constructor TGarbageCollector.Create;
begin
  FObjectList := TObjectList<TObject>.Create;
  FCallbackList := TObjectList<TEventWrapper>.Create;
end;

initialization
  Context := TRttiContext.Create;

finalization
  Context.Free;

end.
