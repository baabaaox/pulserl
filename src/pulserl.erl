%%%-------------------------------------------------------------------
%%% @author Alpha Umaru Shaw <shawalpha5@gmail.com>
%%% @doc
%%%
%%% @end
%%% Copyright: (C) 2020, Skulup Ltd
%%%-------------------------------------------------------------------

-module(pulserl).

-include("pulserl.hrl").
%% API
-export([await/1, await/2]).
-export([produce/2, produce/3, produce/4]).
-export([sync_produce/2, sync_produce/3]).
-export([consume/1, ack/1, ack_cumulative/1, nack/1]).
-export([start_consumption_in_background/1]).

%%--------------------------------------------------------------------
%% @doc
%% @end
%%--------------------------------------------------------------------
produce(PidOrTopic, #prodMessage{} = Msg) ->
  produce(PidOrTopic, Msg, undefined);

%%--------------------------------------------------------------------
%% @doc
%% @end
%%--------------------------------------------------------------------
produce(PidOrTopic, Value) ->
  produce(PidOrTopic, pulserl_producer:new_message(Value), undefined).

%%--------------------------------------------------------------------
%% @doc
%% @end
%%--------------------------------------------------------------------
produce(PidOrTopic, #prodMessage{} = Msg, Callback) ->
  if is_pid(PidOrTopic) ->
    pulserl_producer:produce(PidOrTopic, Msg, Callback);
    true ->
      case pulserl_instance_registry:singleton_producer(PidOrTopic, []) of
        {ok, Pid} -> produce(Pid, Msg, Callback);
        Other -> Other
      end
  end;

%%--------------------------------------------------------------------
%% @doc
%% @end
%%--------------------------------------------------------------------
produce(PidOrTopic, Value, Callback) when is_function(Callback) orelse Callback == ?UNDEF ->
  produce(PidOrTopic, pulserl_producer:new_message(Value), Callback);

produce(PidOrTopic, Key, Value) ->
  produce(PidOrTopic, pulserl_producer:new_message(Key, Value), ?UNDEF).

produce(PidOrTopic, Key, Value, Callback) ->
  produce(PidOrTopic, pulserl_producer:new_message(Key, Value), Callback).


%%--------------------------------------------------------------------
%% @doc
%% @end
%%--------------------------------------------------------------------
sync_produce(Pid, #prodMessage{} = Msg) ->
  sync_produce(Pid, Msg, undefined);

%%--------------------------------------------------------------------
%% @doc
%% @end
%%--------------------------------------------------------------------
sync_produce(PidOrTopic, Value) ->
  sync_produce(PidOrTopic, pulserl_producer:new_message(Value), undefined).

%%--------------------------------------------------------------------
%% @doc
%% @end
%%--------------------------------------------------------------------
sync_produce(PidOrTopic, #prodMessage{} = Msg, Timeout) when
  is_integer(Timeout) orelse Timeout == undefined orelse Timeout == infinity ->
  if is_pid(PidOrTopic) ->
    pulserl_producer:sync_produce(PidOrTopic, Msg, Timeout);
    true ->
      case pulserl_instance_registry:singleton_producer(PidOrTopic, []) of
        {ok, Pid} -> sync_produce(Pid, Msg, Timeout);
        Other -> Other
      end
  end;

%%--------------------------------------------------------------------
%% @doc
%% @end
%%--------------------------------------------------------------------
sync_produce(PidOrTopic, Key, Value) ->
  sync_produce(PidOrTopic, Key, Value, ?UNDEF).

%%--------------------------------------------------------------------
%% @doc
%% @end
%%--------------------------------------------------------------------
sync_produce(PidOrTopic, Key, Value, Timeout) ->
  sync_produce(PidOrTopic, pulserl_producer:new_message(Key, Value), Timeout).


consume(PidOrTopic) ->
  if is_pid(PidOrTopic) ->
    I = pulserl_consumer:receive_message(PidOrTopic),
    %%error_logger:info_msg("Polling Pid: ~p        ~p", [PidOrTopic, I]),
    case I of
      #message{} = Message ->
        #consumedMessage{consumer = PidOrTopic, message = Message};
      Other ->
        Other
    end;
    true ->
      case pulserl_instance_registry:singleton_consumer(PidOrTopic, []) of
        {ok, Pid} -> consume(Pid);
        Else -> Else
      end
  end.

ack(#consumedMessage{consumer = Pid, message = Message}) when is_pid(Pid) ->
  pulserl_consumer:ack(Pid, Message).

ack_cumulative(#consumedMessage{consumer = Pid, message = Message}) when is_pid(Pid) ->
  pulserl_consumer:ack(Pid, Message, true).

nack(#consumedMessage{consumer = Pid, message = Message}) when is_pid(Pid) ->
  pulserl_consumer:nack(Pid, Message).

%%--------------------------------------------------------------------
%% @doc
%% @end
%%--------------------------------------------------------------------
await(Tag) ->
  await(Tag, 10000).

%%--------------------------------------------------------------------
%% @doc
%% @end
%%--------------------------------------------------------------------
await(Tag, Timeout) ->
  receive
    {Tag, Reply} ->
      Reply
  after Timeout ->
    {error, timeout}
  end.


%%% public only for demo purpose
start_consumption_in_background(TopicOrPid) ->
  spawn(fun() -> do_consume(TopicOrPid) end).

do_consume(PidOrTopic) ->
  case consume(PidOrTopic) of
    #consumedMessage{message = #message{value = Value}} = ConsumedMsg ->
      _ = ack(ConsumedMsg),
      io:format("Consumer Received: ~p~n", [Value]);
    {error, Reason} ->
      error_logger:error_msg("Consumer Error. Reason = ~p", [Reason]);
    false ->
      timer:sleep(10),
      ok
  end,
  do_consume(PidOrTopic).