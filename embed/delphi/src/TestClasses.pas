unit TestClasses;

interface

uses
  Classes;

type
  TTestGlobal = class(TObject)
  private
    FProp: string;
    FEvent: TNotifyEvent;
  public
    constructor Create;
    function Func(): string;
    property Prop: string read FProp write FProp;
    property Event: TNotifyEvent read FEvent write FEvent;
  end;

implementation

{ TScriptGlobal }

constructor TTestGlobal.Create;
begin
  FProp := 'TTestGlobal.Prop property';
  FEvent := nil;
end;

function TTestGlobal.Func: string;
begin
  Result := 'Function TTestGlobal.Func called';
end;

end.
