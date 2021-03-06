%% -------------------------------------------------------------------
%%
%% Copyright (c) 2013 Carlos Andres Bolaños, Inc. All Rights Reserved.
%%
%% This file is provided to you under the Apache License,
%% Version 2.0 (the "License", F); you may not use this file
%% except in compliance with the License.  You may obtain
%% a copy of the License at
%%
%%   http://www.apache.org/licenses/LICENSE-2.0
%%
%% Unless required by applicable law or agreed to in writing,
%% software distributed under the License is distributed on an
%% "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
%% KIND, either express or implied.  See the License for the
%% specific language governing permissions and limitations
%% under the License.
%%
%% -------------------------------------------------------------------

%%%-------------------------------------------------------------------
%%% @author Carlos Andres Bolaños R.A. <candres@niagara.io>
%%% @copyright (C) 2013, <Carlos Andres Bolaños>, All Rights Reserved.
%%% @doc Protocol handler. This module handles the incoming events.
%%% @end
%%% Created : 10. Nov 2013 8:59 AM
%%%-------------------------------------------------------------------
-module(west_protocol_handler).

%% API
-export([handle_event/3]).

-include("west.hrl").
-include("west_int.hrl").
-include("west_protocol.hrl").

%%%===================================================================
%%% API
%%%===================================================================

%% @private
%% @doc Handle the ping event.
handle_event(ping, ?MSG{id = Id}, ?WEST{encoding = F}) ->
  {ok, ?RES_PONG(Id, F)};

%% @private
%% @doc Handle the register event.
handle_event(register,
             ?MSG{id = Id, channel = Ch},
             ?WEST{name = Name, scope = Sc, cb = Cb, encoding = F} = WS) ->
  case Ch =/= undefined of
    true ->
      Val = {west_lib, reg, [Sc, {Name, node()}, Ch, Cb]},
      case execute(WS, Ch, Ch, Val) of
        {error, _} ->
          {error, ?RES_INTERNAL_ERROR(Id, F)};
        {_, registration_succeeded, _} ->
          {ok, ?RES_REG_OK(Id, Ch, F)};
        {_, registration_denied, _} ->
          {ok, ?RES_REG_DENIED(Id, Ch, F)};
        {_, registration_already_exist, _} ->
          {ok, ?RES_REG_ALREADY_EXIST(Id, Ch, F)};
        _ ->
          {error, ?RES_REG_FAILED(Id, Ch, F)}
      end;
    _ ->
      {error, ?RES_REG_FAILED(Id, Ch, F)}
  end;

%% @private
%% @doc Handle the unregister event.
handle_event(unregister,
             ?MSG{id = Id, channel = Ch},
             ?WEST{name = Name, encoding = F} = WS) ->
  case Ch =/= undefined of
    true ->
      Val = {west_lib, unreg, [{Name, node()}, Ch]},
      case execute(WS, Ch, Ch, Val) of
        {error, _} ->
          {error, ?RES_INTERNAL_ERROR(Id, F)};
        {_, unregistration_succeeded, _} ->
          {ok, ?RES_UNREG_OK(Id, Ch, F)};
        {_, registration_not_found, _} ->
          {ok, ?RES_REG_NOT_FOUND(Id, Ch, F)};
        _ ->
          {error, ?RES_UNREG_FAILED(Id, Ch, F)}
      end;
    _ ->
      {error, ?RES_UNREG_FAILED(Id, Ch, F)}
  end;

%% @private
%% @doc Handle the send event.
handle_event(send,
             ?MSG{id = Id, channel = Ch, data = Data},
             ?WEST{key = K, scope = Scope, encoding = F} = WS) ->
  case Ch =/= undefined andalso Data =/= undefined of
    true ->
      Val = {west_lib, send, [Scope, K, Ch, Data]},
      case execute(WS, Ch, Ch, Val) of
        {error, _} ->
          {error, ?RES_INTERNAL_ERROR(Id, F)};
        {_, sending_succeeded, _} ->
          {ok, ?RES_SEND_OK(Id, Ch, F)};
        {_, sending_failed, _} ->
          {ok, ?RES_REG_NOT_FOUND(Id, Ch, F)};
        _ ->
          {error, ?RES_SEND_FAILED(Id, Ch, F)}
      end;
    _ ->
      {error, ?RES_SEND_FAILED(Id, Ch, F)}
  end;

%% @private
%% @doc Handle the subscribe event.
handle_event(subscribe,
             ?MSG{id = Id, channel = Ch},
             ?WEST{name = Name, key = K, scope = Sc, cb = Cb, encoding = F} = WS) ->
  case Ch =/= undefined of
    true ->
      Val = {west_lib, sub, [Sc, {Name, node()}, Ch, Cb]},
      case execute(WS, K, Ch, Val) of
        {error, _} ->
          {error, ?RES_INTERNAL_ERROR(Id, F)};
        {_, subscription_succeeded, _} ->
          {ok, ?RES_SUB_OK(Id, Ch, F)};
        {_, subscription_failed, _} ->
          {ok, ?RES_SUB_FAILED(Id, Ch, F)};
        {_, subscription_already_exist, _} ->
          {ok, ?RES_SUB_ALREADY_EXIST(Id, Ch, F)};
        _ ->
          {error, ?RES_SUB_FAILED(Id, Ch, F)}
      end;
    _ ->
      {error, ?RES_SUB_FAILED(Id, Ch, F)}
  end;

%% @private
%% @doc Handle the unsubscribe event.
handle_event(unsubscribe,
             ?MSG{id = Id, channel = Ch},
             ?WEST{name = Name, key = K, encoding = F} = WS) ->
  case Ch =/= undefined of
    true ->
      Val = {west_lib, unsub, [{Name, node()}, Ch]},
      case execute(WS, K, Ch, Val) of
        {error, _} ->
          {error, ?RES_INTERNAL_ERROR(Id, F)};
        {_, unsubscription_succeeded, _} ->
          {ok, ?RES_UNSUB_OK(Id, Ch, F)};
        {_, subscription_not_found, _} ->
          {ok, ?RES_SUB_NOT_FOUND(Id, Ch, F)};
        _ ->
          {error, ?RES_UNSUB_FAILED(Id, Ch, F)}
      end;
    _ ->
      {error, ?RES_UNSUB_FAILED(Id, Ch, F)}
  end;

%% @private
%% @doc Handle the publish event.
handle_event(publish,
             ?MSG{id = Id, channel = Ch, data = Data},
             ?WEST{key = K, dist = Dist, encoding = F}) ->
  case Ch =/= undefined andalso Data =/= undefined of
    true ->
      case Dist of
        gproc_dist ->
          ?PS_PUB(g, K, Ch, Data);
        _ ->
          ?PS_PUB_ALL(l, K, Ch, Data)
      end,
      {ok, ?RES_PUB_OK(Id, Ch, F)};
    _ ->
      {error, ?RES_PUB_FAILED(Id, Ch, F)}
  end;

%% @private
%% @doc Unhandled events.
handle_event(Any, _Msg, _State) ->
  {none, Any}.

%%%===================================================================
%%% Internal functions
%%%===================================================================

%% @private
%% @doc Executes the asked command.
execute(?WEST{dist = Dist, dist_props = PL}, B, K, {M, F, A} = Val) ->
  case Dist of
    west_dist ->
      Opts = west_util:keyfind(opts, PL, []),
      apply(west_dist, cmd, [B, K, Val, Opts]);
    _ ->
      apply(M, F, A)
  end.
