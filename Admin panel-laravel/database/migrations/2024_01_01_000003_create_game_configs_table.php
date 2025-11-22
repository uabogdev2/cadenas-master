<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        Schema::create('game_configs', function (Blueprint $table) {
            $table->id();
            $table->integer('trophies_win')->default(100);
            $table->integer('trophies_loss')->default(100);
            $table->integer('trophies_draw')->default(10);
            $table->integer('game_timer')->default(300);
            $table->integer('question_timer')->default(30);
            $table->string('min_version_android')->default('1.0.0');
            $table->string('min_version_ios')->default('1.0.0');
            $table->boolean('force_update')->default(false);
            $table->boolean('maintenance_mode')->default(false);
            $table->timestamps();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('game_configs');
    }
};
