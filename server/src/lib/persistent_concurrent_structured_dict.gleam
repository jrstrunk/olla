import concurrent_dict
import gleam/dynamic/decode
import gleam/list
import gleam/result
import lib/concurrent_duplicate_dict
import lib/persistent_concurrent_duplicate_dict as pcd_dict

pub opaque type PersistentConcurrentStructuredDict(
  key,
  raw_val,
  topic,
  structured_val,
) {
  PersistentConcurrentStructuredDict(
    raw_data: pcd_dict.PersistentConcurrentDuplicateDict(key, raw_val),
    structured_data: concurrent_dict.ConcurrentDict(topic, structured_val),
    builder: fn(pcd_dict.PersistentConcurrentDuplicateDict(key, raw_val), topic) ->
      structured_val,
    topic_encoder: fn(topic) -> String,
    topic_subscribers: concurrent_duplicate_dict.ConcurrentDuplicateDict(
      topic,
      fn() -> Nil,
    ),
    subscribers: concurrent_duplicate_dict.ConcurrentDuplicateDict(
      Nil,
      fn() -> Nil,
    ),
  )
}

pub fn build(
  path path: String,
  key_encoder key_encoder: fn(key) -> String,
  key_decoder key_decoder: fn(String) -> key,
  example_val example_val: raw_val,
  val_encoder val_encoder: fn(raw_val) -> List(pcd_dict.Value),
  val_decoder val_decoder: decode.Decoder(raw_val),
  topic_encoder topic_encoder: fn(topic) -> String,
  topic_decoder topic_decoder: fn(String) -> topic,
  builder builder: fn(
    pcd_dict.PersistentConcurrentDuplicateDict(key, raw_val),
    topic,
  ) ->
    structured_val,
) {
  use raw_data <- result.map(pcd_dict.build(
    path,
    key_encoder,
    key_decoder,
    example_val,
    val_encoder,
    val_decoder,
  ))

  let structured_data = concurrent_dict.new()

  pcd_dict.topics(raw_data)
  |> list.each(fn(topic: String) {
    let topic = topic_decoder(topic)
    let structured_val = builder(raw_data, topic)
    concurrent_dict.insert(structured_data, topic, structured_val)
  })

  let subscribers = concurrent_duplicate_dict.new()
  let topic_subscribers = concurrent_duplicate_dict.new()

  PersistentConcurrentStructuredDict(
    raw_data:,
    structured_data:,
    builder:,
    topic_encoder:,
    topic_subscribers:,
    subscribers:,
  )
}

pub fn subscribe_to_topic(
  psc_dict: PersistentConcurrentStructuredDict(
    key,
    raw_val,
    topic,
    structured_val,
  ),
  topic,
  subscriber,
) {
  concurrent_duplicate_dict.insert(
    psc_dict.topic_subscribers,
    topic,
    subscriber,
  )
}

pub fn subscribe(
  psc_dict: PersistentConcurrentStructuredDict(
    key,
    raw_val,
    topic,
    structured_val,
  ),
  subscriber,
) {
  concurrent_duplicate_dict.insert(psc_dict.subscribers, Nil, subscriber)
}

pub fn insert(
  psc_dict: PersistentConcurrentStructuredDict(
    key,
    raw_val,
    topic,
    structured_val,
  ),
  key key,
  val val,
  topic topic,
) {
  // If this topic doesn't exist, create it so it can be restored on rebuild
  use Nil <- result.try(pcd_dict.add_topic(
    psc_dict.raw_data,
    psc_dict.topic_encoder(topic),
  ))

  use Nil <- result.map(pcd_dict.insert(psc_dict.raw_data, key, val))

  let structured_val = psc_dict.builder(psc_dict.raw_data, topic)

  concurrent_dict.insert(psc_dict.structured_data, topic, structured_val)

  concurrent_duplicate_dict.get(psc_dict.topic_subscribers, topic)
  |> list.each(fn(effect) { effect() })

  concurrent_duplicate_dict.get(psc_dict.subscribers, Nil)
  |> list.each(fn(effect) { effect() })
}

pub fn get(
  psc_dict: PersistentConcurrentStructuredDict(
    key,
    raw_val,
    topic,
    structured_val,
  ),
  topic topic,
) -> Result(structured_val, Nil) {
  concurrent_dict.get(psc_dict.structured_data, topic)
}

pub fn to_list(
  psc_dict: PersistentConcurrentStructuredDict(
    key,
    raw_val,
    topic,
    structured_val,
  ),
) {
  concurrent_dict.to_list(psc_dict.structured_data)
}
