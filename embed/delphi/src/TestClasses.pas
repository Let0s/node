unit TestClasses;

interface

type
  TTestGlobal = class(TObject)
  private
    function GetProp: string;
  public
    function Func(): string;
    property Prop: string read GetProp;
  end;

implementation

{ TScriptGlobal }

function TTestGlobal.Func: string;
begin
  Result := 'Function TTestGlobal.Func called';
end;

function TTestGlobal.GetProp: string;
begin
  Result := 'TTestGlobal.GetProp called';
end;

end.
