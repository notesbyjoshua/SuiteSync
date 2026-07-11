-- Store the YYGS academic track separately from the program session.
alter table public.survey_responses
  add column if not exists track text;

comment on column public.survey_responses.track is
'YYGS academic track selected by the applicant.';

comment on column public.survey_responses.session is
'YYGS program session: Session I, Session II, or Session III. Earlier responses may contain a track name in this column.';
