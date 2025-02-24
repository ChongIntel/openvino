// Copyright (C) 2018-2022 Intel Corporation
// SPDX-License-Identifier: Apache-2.0
//

#include "cum_sum_inst.h"
#include "primitive_base.hpp"
#include "impls/implementation_map.hpp"
#include "kernel_selector_helper.h"
#include "cum_sum/cum_sum_kernel_selector.h"
#include "cum_sum/cum_sum_kernel_ref.h"
#include "intel_gpu/runtime/error_handler.hpp"

using namespace cldnn;
namespace cldnn {
namespace ocl {

namespace {
kernel_selector::cum_sum_axis convert_axis(int64_t axis, size_t rank) {
    if (axis < 0) {
        axis += rank;
    }
    switch (axis) {
        case 0: return kernel_selector::cum_sum_axis::BATCH;
        case 1: return kernel_selector::cum_sum_axis::FEATURE;
        case 2:
            if (rank == 6)
                return kernel_selector::cum_sum_axis::W;
            else if (rank == 5)
                return kernel_selector::cum_sum_axis::Z;
            else
                return kernel_selector::cum_sum_axis::Y;
        case 3:
            if (rank == 6)
                return kernel_selector::cum_sum_axis::Z;
            else if (rank == 5)
                return kernel_selector::cum_sum_axis::Y;
            else
                return kernel_selector::cum_sum_axis::X;
        case 4:
            if (rank == 6)
                return kernel_selector::cum_sum_axis::Y;
            else
                return kernel_selector::cum_sum_axis::X;
        case 5: return kernel_selector::cum_sum_axis::X;
        default: return kernel_selector::cum_sum_axis::BATCH;
    }
}
}  // namespace

struct cum_sum_impl : typed_primitive_impl_ocl<cum_sum> {
    using parent = typed_primitive_impl_ocl<cum_sum>;
    using parent::parent;
    using kernel_selector_t = kernel_selector::cum_sum_kernel_selector;
    using kernel_params_t = std::pair<kernel_selector::cum_sum_params, kernel_selector::cum_sum_optional_params>;

    DECLARE_OBJECT_TYPE_SERIALIZATION

    std::unique_ptr<primitive_impl> clone() const override {
        return make_unique<cum_sum_impl>(*this);
    }

public:
    static kernel_params_t get_kernel_params(const kernel_impl_params& impl_param) {
        const auto& primitive = impl_param.typed_desc<cum_sum>();
        auto params = get_default_params<kernel_selector::cum_sum_params>(impl_param);
        auto optional_params = get_default_optional_params<kernel_selector::cum_sum_optional_params>(impl_param.get_program());

        size_t rank = impl_param.get_output_layout().get_rank();
        params.axis = convert_axis(primitive->axis, rank);
        params.exclusive = primitive->exclusive;
        params.reverse = primitive->reverse;
        return {params, optional_params};
    }
};

namespace detail {

attach_cum_sum_impl::attach_cum_sum_impl() {
    implementation_map<cum_sum>::add(impl_types::ocl, typed_primitive_impl_ocl<cum_sum>::create<cum_sum_impl>, {
        std::make_tuple(data_types::i32, format::bfyx),
        std::make_tuple(data_types::i32, format::bfzyx),
        std::make_tuple(data_types::i32, format::bfwzyx),
        std::make_tuple(data_types::i64, format::bfyx),
        std::make_tuple(data_types::i64, format::bfzyx),
        std::make_tuple(data_types::i64, format::bfwzyx),
        std::make_tuple(data_types::f16, format::bfyx),
        std::make_tuple(data_types::f16, format::bfzyx),
        std::make_tuple(data_types::f16, format::bfwzyx),
        std::make_tuple(data_types::f32, format::bfyx),
        std::make_tuple(data_types::f32, format::bfzyx),
        std::make_tuple(data_types::f32, format::bfwzyx),
    });
}

}  // namespace detail
}  // namespace ocl
}  // namespace cldnn

BIND_BINARY_BUFFER_WITH_TYPE(cldnn::ocl::cum_sum_impl)
