

use JSON;
use JSON::WebToken;

	my $time = time;


	my $jwt = JSON::WebToken->encode(
    {
        # your service account id here
        iss   => 'test',
        scope => 'https://www.googleapis.com/auth/drive',
        aud   => 'https://accounts.google.com/o/oauth2/token',
        exp   => $time + 3600,
        iat   => $time,
        # To access the google admin sdk with a service account
        # the service account must act on behalf of an account
        # that has admin privileges on the domain
        # Otherwise the token will be returned but API calls
        # will generate a 403
        prn => 'test',
    },
    'abc',
    'RS256',
    { typ => 'JWT' }
);

