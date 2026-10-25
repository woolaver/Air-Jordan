function require_fields(s, names, caller)
% Fails early, with one clear message, if the aircraft struct lacks a field.
missing = names(~isfield(s, names));
if ~isempty(missing)
    error('%s: aircraft struct is missing field(s): %s', caller, strjoin(missing, ', '));
end
end