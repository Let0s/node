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
    function Func(argument: string): string;
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

function TTestGlobal.Func(argument: string): string;
begin
  Result := 'Function TTestGlobal.Func called. argument = ' + argument;
end;

end.
