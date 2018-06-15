unit TestClasses;

interface

uses
  Math, TestRecords, TestInterfaces, Classes, TestHelpers;

type

  TTestFigureType = (tftCircle, tftRect, tftCustom);

  TTestPointArray = array of TTestPoint;
  T2PointArray = array [0..1] of TTestPoint;

  TTestFigure = class(TInterfacedObject, ITestFigure)
  public
    function GetSquare: double;
  end;

  TTestFigureArray = array of TTestFigure;

  TTestCircle = class(TTestFigure)
  private
    FRadius: double;
    FCenter: TTestPoint;
  public
    constructor Create(CenterPoint: TTestPoint; Radius: double);
    property Center: TTestPoint read FCenter write FCenter;
    property Radius: double read FRadius;
    function GetSquare: double;
  end;

  TTestRectangle = class(TTestFigure)
  private
    FMin: TTestPoint;
    FMax: TTestPoint;
  public
    constructor Create(MinPoint, MaxPoint: TTestPoint);
    property Min: TTestPoint read FMin;
    property Max: TTestPoint read FMax;
    function GetSquare: double;
    function AsPoints: T2PointArray;
  end;

  TCustomFigure = class(TTestFigure)
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
    function CreateRectangles(sizes: TArray<Double>): TTestFigureArray;
    function CreateRectangle(StartPoint, EndPoint: TTestPoint): TTestRectangle;
    function CreateCircle(Radius: double): TTestCircle; overload;
    function CreateCircle(CenterPoint: TTestPoint;
      Radius: double): TTestCircle; overload;
    function CreateFigure(figType: TTestFigureType): TTestFigure;
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

function TTestGlobal.CreateFigure(figType: TTestFigureType): TTestFigure;
begin
  Result := nil;
  case figType of
    tftCircle: Result := CreateCircle(1);
    tftRect: Result := CreateRectangle(TTestPoint.Create(0, 0),
      TTestPoint.Create(1, 1));
    tftCustom: Result := CreateCustomFigure;
  end;
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

function TTestGlobal.CreateRectangles(sizes: TArray<Double>): TTestFigureArray;
var
  L: Integer;
  i: Integer;
  Size: double;
  Point: TTestPoint;
  Rect: TTestRectangle;
begin
  L := Length(sizes);
  SetLength(Result, L);
  Point.x := 0;
  Point.y := 0;
  for i := 0 to L - 1 do
  begin
    Size := sizes[i];
    Rect := TTestRectangle.Create(Point, TTestPoint.Create(size, size));
    Result[i] := Rect;
  end;
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

function TTestRectangle.AsPoints: T2PointArray;
begin
  Result[0] := Min;
  Result[1] := Max;
end;

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
{ TTestFigure }

function TTestFigure.GetSquare: double;
begin
  Result := -1;
end;

end.
