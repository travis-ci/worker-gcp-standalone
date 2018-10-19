[Application Options]
SampleRate = ${sample_rate}
AddFields = app=worker

[Required Options]
ParserName = keyval
LogFiles = -
WriteKey = ${writekey}
Dataset = ${dataset}

[KeyVal Parser Options]
TimeFieldName = time
FilterRegex = time=
