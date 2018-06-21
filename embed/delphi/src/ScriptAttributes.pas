unit ScriptAttributes;

interface
uses
  Classes;

type
  TScriptAttributeType = (
    // Return value should be stored in garbage collector
    satGarbage,
    // Property/method/field/class shouldn't be available in JS
    satForbidden
  );

  TScriptAttributeSettings = set of TScriptAttributeType;

  TScriptAttribute = class(TCustomAttribute)
  private
    FSettings: TScriptAttributeSettings;
  public
    constructor Create(settings: TScriptAttributeSettings);
    function HaveSetting(setting: TScriptAttributeType): Boolean;
  end;

implementation

{ TScriptAttribute }

constructor TScriptAttribute.Create(settings: TScriptAttributeSettings);
begin
  FSettings := settings;
end;

function TScriptAttribute.HaveSetting(
  setting: TScriptAttributeType): Boolean;
begin
  Result := setting in FSettings;
end;

end.
