unit EngineHelper;

interface

uses
  NodeInterface, RTTI, TypInfo;


  function TValueToJSValue(value: TValue; Engine: INodeEngine): IJSValue;

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

end.
