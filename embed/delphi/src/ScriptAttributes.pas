unit ScriptAttributes;

interface
uses
  Classes;

type
  TScriptAttributeType = (
    // Return value should be stored in garbage collector
    satGarbage,
    // Property/method shouldn't be available in JS
    satForbiddenProp,
    // Class shouldn't be available in JS
    // If method/prop have this setting, it must return undefined
    satForbiddenClass
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
