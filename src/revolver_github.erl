-module(revolver_github).
-export([start/1]).
-export([init/3, handle/2, terminate/2]).
-export([unquote/1]).

dispatch() ->
    [%% {Host, list({Path, Handler, Opts})}
    {'_', [{'_', revolver_github, []}]}].

start(Port) ->
    application:start(cowboy),

    %% Name, NbAcceptors, Transport, TransOpts, Protocol, ProtoOpts
    cowboy:start_listener(http, 100,
        cowboy_tcp_transport, [{port, Port}],
        cowboy_http_protocol, [{dispatch, dispatch()}]).


init({tcp, http}, Req, Opts) ->
    %erlang:display(Req),
    %erlang:display(Opts),
    {ok, Req, undefined}.

handle(Req, State) ->
    {QS, R1} = cowboy_http_req:body_qs(Req),
    QuotedPayload = proplists:get_value("payload", QS),
    UnquotedPayload = unquote(QuotedPayload),
    Payload = jsx:json_to_term(UnquotedPayload, [{strict, false}]),
    erlang:display(Payload),
    {ok, R2} = cowboy_http_req:reply(200, [], "", Req),
    {ok, R2, State}.

terminate(Req, State) ->
    ok.


%% Function for unquoting query string parameters borrowed from mochiweb.
%% slightly modified to not use an accumulator and to also match on commonly
%% used characters instead of computing the value of each quoted character.
-define(IS_HEX(C),
    ((C >= $0 andalso C =< $9) orelse
     (C >= $a andalso C =< $f) orelse
     (C >= $A andalso C =< $F))).

unquote(String) when is_list(String) ->
    unquote_(String).

%% Space
unquote_("+"   ++ T) -> [($\ )|unquote_(T)];
unquote_("%20" ++ T) -> [($\ )|unquote_(T)];
%% {
unquote_("%7B" ++ T) -> [($\{)|unquote_(T)];
unquote_("%7b" ++ T) -> [($\{)|unquote_(T)];
%% }
unquote_("%7D" ++ T) -> [($\})|unquote_(T)];
unquote_("%7d" ++ T) -> [($\})|unquote_(T)];
%% |
unquote_("%7C" ++ T) -> [($\|)|unquote_(T)];
unquote_("%7c" ++ T) -> [($\|)|unquote_(T)];
%% \
unquote_("%5C" ++ T) -> [($\\)|unquote_(T)];
unquote_("%5c" ++ T) -> [($\\)|unquote_(T)];
%% ^
unquote_("%5E" ++ T) -> [($^ )|unquote_(T)];
unquote_("%5e" ++ T) -> [($^ )|unquote_(T)];
%% ~
unquote_("%7E" ++ T) -> [($\~)|unquote_(T)];
unquote_("%7e" ++ T) -> [($\~)|unquote_(T)];
%% [
unquote_("%5B" ++ T) -> [($\[)|unquote_(T)];
unquote_("%5b" ++ T) -> [($\[)|unquote_(T)];
%% ]
unquote_("%5D" ++ T) -> [($\])|unquote_(T)];
unquote_("%5d" ++ T) -> [($\])|unquote_(T)];
%% `
unquote_("%60" ++ T) -> [($\`)|unquote_(T)];
%% "
unquote_("%22" ++ T) -> [($" )|unquote_(T)];
%% Maybe quoted
unquote_("%"   ++ [High,Low|T]) when ?IS_HEX(Low), ?IS_HEX(High) ->
    [(unhex(Low) bor (unhex(High) bsl 4))|unquote_(T)];
%% Not quoted
unquote_([Char|T]) -> [Char|unquote_(T)];
%% Basecase
unquote_([]) -> [].

%% Assume that C falls withing the valid range
unhex(C) when C >= $a -> C - 87; % C - $a + 10
unhex(C) when C >= $A -> C - 55; % C - $A + 10
unhex(C) when C >= $0 -> C - $0.
