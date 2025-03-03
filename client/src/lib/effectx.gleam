import lustre/effect
import o11a/selector

pub fn focus_line_discussion_input(line_tag) {
  use _ <- effect.from
  selector.focus_line_discussion_input(line_tag)
}
