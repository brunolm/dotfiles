function cup { docker-compose up $args }
function cr { docker-compose run --service-ports --rm $args }

function crl { docker-compose run --service-ports --rm local $args }
function crd { docker-compose run --service-ports --rm develop $args }
function crp { docker-compose run --service-ports --rm production $args }
function crb { docker-compose run --service-ports --rm build $args }
function crs { docker-compose run --service-ports --rm setup $args }

function crt { docker-compose run --rm test $args }
function crci { docker-compose run --rm ci $args }
