unit Horse.Provider.VCL;

interface

{$IF DEFINED(HORSE_VCL)}
uses
  Horse.Provider.Abstract, Horse.Constants, Horse.Provider.IOHandleSSL,
  IdHTTPWebBrokerBridge, IdSSLOpenSSL, IdContext,
  System.Classes, System.SyncObjs, System.SysUtils;

type
  THorseProvider<T: class> = class(THorseProviderAbstract<T>)
  private
    class var FPort: Integer;
    class var FHost: string;
    class var FRunning: Boolean;
    class var FEvent: TEvent;
    class var FMaxConnections: Integer;
    class var FListenQueue: Integer;
    class var FIdHTTPWebBrokerBridge: TIdHTTPWebBrokerBridge;
    class var FHorseProviderIOHandleSSL: THorseProviderIOHandleSSL;
    class function GetDefaultHTTPWebBroker: TIdHTTPWebBrokerBridge;
    class function GetDefaultHorseProviderIOHandleSSL: THorseProviderIOHandleSSL;
    class function GetDefaultEvent: TEvent;
    class function HTTPWebBrokerIsNil: Boolean;
    class procedure OnAuthentication(AContext: TIdContext; const AAuthType, AAuthData: string; var VUsername, VPassword: string; var VHandled: Boolean);
    class procedure OnQuerySSLPort(APort: Word; var VUseSSL: Boolean);
    class procedure SetListenQueue(const Value: Integer); static;
    class procedure SetMaxConnections(const Value: Integer); static;
    class procedure SetPort(const Value: Integer); static;
    class procedure SetIOHandleSSL(const Value: THorseProviderIOHandleSSL); static;
    class procedure SetHost(const Value: string); static;
    class function GetListenQueue: Integer; static;
    class function GetMaxConnections: Integer; static;
    class function GetPort: Integer; static;
    class function GetDefaultPort: Integer; static;
    class function GetDefaultHost: string; static;
    class function GetIOHandleSSL: THorseProviderIOHandleSSL; static;
    class function GetHost: string; static;
    class procedure InternalListen; virtual;
    class procedure InternalStopListen; virtual;
    class procedure InitServerIOHandlerSSLOpenSSL(AIdHTTPWebBrokerBridge: TIdHTTPWebBrokerBridge; FHorseProviderIOHandleSSL: THorseProviderIOHandleSSL);
  public
    constructor Create; reintroduce; overload;
    constructor Create(APort: Integer); reintroduce; overload; deprecated 'Use Port method to set port';
    class property Host: string read GetHost write SetHost;
    class property Port: Integer read GetPort write SetPort;
    class property MaxConnections: Integer read GetMaxConnections write SetMaxConnections;
    class property ListenQueue: Integer read GetListenQueue write SetListenQueue;
    class property IOHandleSSL: THorseProviderIOHandleSSL read GetIOHandleSSL write SetIOHandleSSL;
    class procedure Listen; overload; override;
    class procedure StopListen; override;
    class procedure Listen(APort: Integer; const AHost: string = '0.0.0.0'; ACallback: TProc<T> = nil); reintroduce; overload; static;
    class procedure Listen(APort: Integer; ACallback: TProc<T>); reintroduce; overload; static;
    class procedure Listen(AHost: string; const ACallback: TProc<T> = nil); reintroduce; overload; static;
    class procedure Listen(ACallback: TProc<T>); reintroduce; overload; static;
    class procedure Start; deprecated 'Use Listen instead';
    class procedure Stop; deprecated 'Use StopListen instead';
    class function IsRunning: Boolean;
    class destructor UnInitialize;
  end;
{$ENDIF}

implementation

{$IF DEFINED(HORSE_VCL)}

uses
  Web.WebReq, Horse.WebModule, IdCustomTCPServer;

{ THorseProvider<T> }

class function THorseProvider<T>.IsRunning: Boolean;
begin
  Result := FRunning;
end;

class function THorseProvider<T>.GetDefaultHTTPWebBroker: TIdHTTPWebBrokerBridge;
begin
  if HTTPWebBrokerIsNil then
  begin
    FIdHTTPWebBrokerBridge := TIdHTTPWebBrokerBridge.Create(nil);
    FIdHTTPWebBrokerBridge.OnParseAuthentication := OnAuthentication;
    FIdHTTPWebBrokerBridge.OnQuerySSLPort := OnQuerySSLPort;
  end;
  Result := FIdHTTPWebBrokerBridge;
end;

class function THorseProvider<T>.HTTPWebBrokerIsNil: Boolean;
begin
  Result := FIdHTTPWebBrokerBridge = nil;
end;

class procedure THorseProvider<T>.OnQuerySSLPort(APort: Word; var VUseSSL: Boolean);
begin
  VUseSSL := (FHorseProviderIOHandleSSL <> nil) and (FHorseProviderIOHandleSSL.Active);
end;

constructor THorseProvider<T>.Create(APort: Integer);
begin
  inherited Create;
  SetPort(APort);
end;

constructor THorseProvider<T>.Create;
begin
  inherited Create;
end;

class function THorseProvider<T>.GetDefaultEvent: TEvent;
begin
  if FEvent = nil then
    FEvent := TEvent.Create;
  Result := FEvent;
end;

class function THorseProvider<T>.GetDefaultHorseProviderIOHandleSSL: THorseProviderIOHandleSSL;
begin
  if FHorseProviderIOHandleSSL = nil then
    FHorseProviderIOHandleSSL := THorseProviderIOHandleSSL.Create;
  Result := FHorseProviderIOHandleSSL;
end;

class function THorseProvider<T>.GetDefaultHost: string;
begin
  Result := DEFAULT_HOST;
end;

class function THorseProvider<T>.GetDefaultPort: Integer;
begin
  Result := DEFAULT_PORT;
end;

class function THorseProvider<T>.GetHost: string;
begin
  Result := FHost;
end;

class function THorseProvider<T>.GetIOHandleSSL: THorseProviderIOHandleSSL;
begin
  Result := GetDefaultHorseProviderIOHandleSSL;
end;

class function THorseProvider<T>.GetListenQueue: Integer;
begin
  Result := FListenQueue;
end;

class function THorseProvider<T>.GetMaxConnections: Integer;
begin
  Result := FMaxConnections;
end;

class function THorseProvider<T>.GetPort: Integer;
begin
  Result := FPort;
end;

class procedure THorseProvider<T>.InitServerIOHandlerSSLOpenSSL(AIdHTTPWebBrokerBridge: TIdHTTPWebBrokerBridge; FHorseProviderIOHandleSSL: THorseProviderIOHandleSSL);
var
  LIOHandleSSL: TIdServerIOHandlerSSLOpenSSL;
begin
  LIOHandleSSL := TIdServerIOHandlerSSLOpenSSL.Create(AIdHTTPWebBrokerBridge);
  LIOHandleSSL.SSLOptions.CertFile := FHorseProviderIOHandleSSL.CertFile;
  LIOHandleSSL.SSLOptions.RootCertFile := FHorseProviderIOHandleSSL.RootCertFile;
  LIOHandleSSL.SSLOptions.KeyFile := FHorseProviderIOHandleSSL.KeyFile;
  LIOHandleSSL.SSLOptions.Method := FHorseProviderIOHandleSSL.Method;
  LIOHandleSSL.SSLOptions.SSLVersions := FHorseProviderIOHandleSSL.SSLVersions;
  LIOHandleSSL.OnGetPassword := FHorseProviderIOHandleSSL.OnGetPassword;
  AIdHTTPWebBrokerBridge.IOHandler := LIOHandleSSL;
end;

class procedure THorseProvider<T>.InternalListen;
var
  LAttach: string;
  LIdHTTPWebBrokerBridge: TIdHTTPWebBrokerBridge;
begin
  inherited;
  if FPort <= 0 then
    FPort := GetDefaultPort;
  if FHost.IsEmpty then
    FHost := GetDefaultHost;

  LIdHTTPWebBrokerBridge := GetDefaultHTTPWebBroker;
  WebRequestHandler.WebModuleClass := WebModuleClass;
  try
    if FMaxConnections > 0 then
    begin
      WebRequestHandler.MaxConnections := FMaxConnections;
      GetDefaultHTTPWebBroker.MaxConnections := FMaxConnections;
    end;

    if FListenQueue = 0 then
      FListenQueue := IdListenQueueDefault;

    if FHorseProviderIOHandleSSL <> nil then
      InitServerIOHandlerSSLOpenSSL(LIdHTTPWebBrokerBridge, GetDefaultHorseProviderIOHandleSSL);

    LIdHTTPWebBrokerBridge.ListenQueue := FListenQueue;
    
    LIdHTTPWebBrokerBridge.Bindings.Clear;
    if FHost <> GetDefaultHost then
    begin
      LIdHTTPWebBrokerBridge.Bindings.Add;
      LIdHTTPWebBrokerBridge.Bindings.Items[0].IP := FHost;
      LIdHTTPWebBrokerBridge.Bindings.Items[0].Port := FPort;
    end;

    LIdHTTPWebBrokerBridge.DefaultPort := FPort;
    LIdHTTPWebBrokerBridge.Active := True;
    LIdHTTPWebBrokerBridge.StartListening;
    FRunning := True;
    DoOnListen;
  except
    raise;
  end;
end;

class procedure THorseProvider<T>.InternalStopListen;
begin
  if not HTTPWebBrokerIsNil then
  begin
    GetDefaultHTTPWebBroker.StopListening;
    GetDefaultHTTPWebBroker.Active := False;    
    FRunning := False;
    if FEvent <> nil then
      GetDefaultEvent.SetEvent;
  end
  else
    raise Exception.Create('Horse not listen');
end;

class procedure THorseProvider<T>.Start;
begin
  Listen;
end;

class procedure THorseProvider<T>.Stop;
begin
  StopListen;
end;

class procedure THorseProvider<T>.StopListen;
begin
  InternalStopListen;
end;

class procedure THorseProvider<T>.Listen;
begin
  InternalListen;
end;

class procedure THorseProvider<T>.Listen(APort: Integer; const AHost: string; ACallback: TProc<T>);
begin
  SetPort(APort);
  SetHost(AHost);
  SetOnListen(ACallback);
  InternalListen;
end;

class procedure THorseProvider<T>.Listen(AHost: string; const ACallback: TProc<T>);
begin
  Listen(FPort, AHost, ACallback);
end;

class procedure THorseProvider<T>.Listen(ACallback: TProc<T>);
begin
  Listen(FPort, FHost, ACallback);
end;

class procedure THorseProvider<T>.Listen(APort: Integer; ACallback: TProc<T>);
begin
  Listen(APort, FHost, ACallback);
end;

class procedure THorseProvider<T>.OnAuthentication(AContext: TIdContext; const AAuthType, AAuthData: string; var VUsername, VPassword: string; var VHandled: Boolean);
begin
  VHandled := True;
end;

class procedure THorseProvider<T>.SetHost(const Value: string);
begin
  FHost := Value.Trim;
end;

class procedure THorseProvider<T>.SetIOHandleSSL(const Value: THorseProviderIOHandleSSL);
begin
  FHorseProviderIOHandleSSL := Value;
end;

class procedure THorseProvider<T>.SetListenQueue(const Value: Integer);
begin
  FListenQueue := Value;
end;

class procedure THorseProvider<T>.SetMaxConnections(const Value: Integer);
begin
  FMaxConnections := Value;
end;

class procedure THorseProvider<T>.SetPort(const Value: Integer);
begin
  FPort := Value;
end;

class destructor THorseProvider<T>.UnInitialize;
begin
  FreeAndNil(FIdHTTPWebBrokerBridge);
  if FEvent <> nil then
    FreeAndNil(FEvent);
  if FHorseProviderIOHandleSSL <> nil then
    FreeAndNil(FHorseProviderIOHandleSSL);
end;

{$ENDIF}

end.
