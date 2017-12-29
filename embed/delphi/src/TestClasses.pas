unit TestClasses;

interface

uses
  Classes;

type
  TTestParent = class(TObject)
  private
    Fprop: string;
    procedure Setprop(const Value: string);
  public
    constructor Create;
    property prop: string read Fprop write Setprop;
  end;

  TTestGlobal = class(TObject)
  private
    FProp: string;
    FEvent: TNotifyEvent;
    Fobj: TTestParent;
    procedure Setobj(const Value: TTestParent);
  public
    constructor Create;
    destructor Destroy; override;
    function Func(argument: string): string;
    property Prop: string read FProp write FProp;
    property Event: TNotifyEvent read FEvent write FEvent;
    property obj: TTestParent read Fobj write Setobj;
  end;

implementation

{ TScriptGlobal }

constructor TTestGlobal.Create;
begin
  FProp := 'TTestGlobal.Prop property';
  Fobj := TTestParent.Create;
  FEvent := nil;
end;

destructor TTestGlobal.Destroy;
begin
  Fobj.Free;
  inherited;
end;

function TTestGlobal.Func(argument: string): string;
begin
  Result := 'Function TTestGlobal.Func called. argument = ' + argument;
end;

procedure TTestGlobal.Setobj(const Value: TTestParent);
begin
  Fobj := Value;
end;

{ TTestParent }

constructor TTestParent.Create;
begin
  Fprop := 'TTestParent.Prop property';
end;

procedure TTestParent.Setprop(const Value: string);
begin
  Fprop := Value;
end;

end.
