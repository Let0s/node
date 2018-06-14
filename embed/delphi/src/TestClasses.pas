unit TestClasses;

interface

uses
  Math, TestRecords, TestInterfaces, Classes, TestHelpers;

type

  TTestCircle = class(TInterfacedObject, ITestFigure)
  private
    FRadius: double;
    FCenter: TTestPoint;
  public
    constructor Create(CenterPoint: TTestPoint; Radius: double);
    property Center: TTestPoint read FCenter write FCenter;
    property Radius: double read FRadius;
    function GetSquare: double;
  end;

  TTestRectangle = class(TInterfacedObject, ITestFigure)
  private
    FMin: TTestPoint;
    FMax: TTestPoint;
  public
    constructor Create(MinPoint, MaxPoint: TTestPoint);
    property Min: TTestPoint read FMin;
    property Max: TTestPoint read FMax;
    function GetSquare: double;
  end;

  TCustomFigure = class(TInterfacedObject, ITestFigure)
  private
    FOnGetSquare: TGetEvent;
  public
    property OnGetSquare: TGetEvent read FOnGetSquare write FOnGetSquare;
    function GetSquare: double;
  end;

  TTestGlobal = class(TObject)
  private
    FOnGetFigure: TNotifyEvent;
    function GetFive: integer;
  public
    Four: Integer;
    constructor Create;
    destructor Destroy; override;
    property Five: integer read GetFive;
    property OnGetFigure: TNotifyEvent read FOnGetFigure write FOnGetFigure;
    function CreateRandomFigure: ITestFigure;
    function CreateCustomFigure: TCustomFigure;
    function CreateRectangle(StartPoint, EndPoint: TTestPoint): TTestRectangle;
    function CreateCircle(Radius: double): TTestCircle; overload;
    function CreateCircle(CenterPoint: TTestPoint;
      Radius: double): TTestCircle; overload;
  end;

implementation

{ TScriptGlobal }

constructor TTestGlobal.Create;
begin
  Four := 4;
end;

function TTestGlobal.CreateCircle(Radius: double): TTestCircle;
begin
  Result := TTestCircle.Create(TTestPoint.Create(0, 0), Radius);
  if Assigned(FOnGetFigure) then
    FOnGetFigure(Result)
end;

function TTestGlobal.CreateCircle(CenterPoint: TTestPoint;
  Radius: double): TTestCircle;
begin
  Result := TTestCircle.Create(CenterPoint, Radius);
  if Assigned(FOnGetFigure) then
    FOnGetFigure(Result)
end;

function TTestGlobal.CreateCustomFigure: TCustomFigure;
begin
  Result := TCustomFigure.Create;
end;

function TTestGlobal.CreateRandomFigure: ITestFigure;
begin
  //not random, but returns interface
  Result := TTestCircle.Create(TTestPoint.Create(0, 0), 5);
  if Assigned(FOnGetFigure) then
    FOnGetFigure(TObject(Result))
end;

function TTestGlobal.CreateRectangle(StartPoint,
  EndPoint: TTestPoint): TTestRectangle;
begin
  Result := TTestRectangle.Create(StartPoint, EndPoint);
  if Assigned(FOnGetFigure) then
    FOnGetFigure(Result)
end;

destructor TTestGlobal.Destroy;
begin
  inherited;
end;

function TTestGlobal.GetFive: integer;
begin
  Result := 5;
end;

{ TTestCircle }

constructor TTestCircle.Create(CenterPoint: TTestPoint; Radius: double);
begin
  FRadius := Radius;
  FCenter := CenterPoint;
end;

function TTestCircle.GetSquare: double;
begin
  Result := 2 * FRadius * Pi;
end;

{ TTestRectangle }

constructor TTestRectangle.Create(MinPoint, MaxPoint: TTestPoint);
begin
  FMin := MinPoint;
  FMax := MaxPoint;
end;

function TTestRectangle.GetSquare: double;
begin
  Result := (Abs(FMin.x - FMax.x) * Abs(FMax.y - FMin.y));
end;

{ TCustomFigure }

function TCustomFigure.GetSquare: double;
begin
  if Assigned(FOnGetSquare) then
    Result := FOnGetSquare(Self)
  else
    Result := 0;
end;
end.
