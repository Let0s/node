unit TestClasses;

interface

type
  TTestGlobal = class(TObject)
  public
    function Func(): string;
  end;

implementation

{ TScriptGlobal }

function TTestGlobal.Func: string;
begin
  Result := 'Function TTestGlobal.Func called';
end;

end.
