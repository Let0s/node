unit EngineHelper;

interface

uses
  NodeInterface, RTTI, TypInfo;


  function TValueToJSValue(value: TValue; Engine: INodeEngine): IJSValue;

  function JSValueToTValue(value: IJSValue; typ: TRttiType;
    Engine: INodeEngine): TValue;

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


function JSValueToTValue(value: IJSValue; typ: TRttiType;
  Engine: INodeEngine): TValue;
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

initialization
  Context := TRttiContext.Create;

finalization
  Context.Free;

end.
