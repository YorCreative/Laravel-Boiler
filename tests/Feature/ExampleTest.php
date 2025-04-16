<?php

namespace Tests\Feature;

use Illuminate\Support\Facades\DB;
use Tests\TestCase;

class ExampleTest extends TestCase
{
    public function test_the_application_returns_a_successful_response(): void
    {
        $response = $this->get('/');

        $response->assertStatus(200);
    }

    public function test_the_application_is_connected_to_testing_mysql_database(): void
    {
        $this->assertEquals('laravel_boiler_testing', DB::getDatabaseName());
    }
}
