"""
健康检查路由
"""
from flask import Blueprint, jsonify
from datetime import datetime

health_bp = Blueprint('health', __name__)


@health_bp.route('/api/status', methods=['GET'])
def index():
    """API 状态（原 / 已用于单镜像时托管前端，故迁至 /api/status）"""
    return jsonify({
        'name': 'QuantDinger Python API',
        'version': '2.0.0',
        'status': 'running',
        'timestamp': datetime.now().isoformat()
    })


@health_bp.route('/health', methods=['GET'])
def health_check():
    """健康检查"""
    return jsonify({
        'status': 'healthy',
        'timestamp': datetime.now().isoformat()
    })


@health_bp.route('/api/health', methods=['GET'])
def api_health_check():
    """兼容路径：用于容器健康检查/反代探针等场景。"""
    return health_check()
