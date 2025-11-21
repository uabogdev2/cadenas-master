<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class UserStats extends Model
{
    use HasFactory;

    protected $table = 'user_stats';

    protected $primaryKey = 'userId';

    public $incrementing = false;

    protected $keyType = 'string';

    public const CREATED_AT = 'createdAt';
    public const UPDATED_AT = 'updatedAt';

    protected $fillable = [
        'userId',
        'totalAttempts',
        'totalPlayTime',
        'bestTimes',
        'createdAt',
        'updatedAt',
    ];

    protected $casts = [
        'totalAttempts' => 'integer',
        'totalPlayTime' => 'integer',
        'bestTimes' => 'array',
        'createdAt' => 'datetime',
        'updatedAt' => 'datetime',
    ];

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class, 'userId');
    }
}

