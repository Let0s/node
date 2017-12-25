unit TestClasses;

interface

type
  TTestGlobal = class(TObject)
  private
    FProp: string;
  public
    constructor Create;
    function Func(): string;
    property Prop: string read FProp write FProp;
  end;

implementation

{ TScriptGlobal }

constructor TTestGlobal.Create;
begin
  FProp := 'TTestGlobal.Prop property';
end;

function TTestGlobal.Func: string;
begin
  Result := 'Function TTestGlobal.Func called';
end;

end.
